import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leaderboard_entry.dart';
import '../models/league.dart';

import 'api_client.dart';

class LeagueService extends ChangeNotifier {
  static final LeagueService _instance = LeagueService._internal();
  factory LeagueService() => _instance;
  LeagueService._internal() {
    loadData();
  }

  static const String _leaguesPrefKey = 'domino_leagues_registry_v1';
  static const String _activeLeaguePrefKey = 'domino_active_league_id_v1';

  final Map<String, League> _leagues = {};
  String? _activeLeagueId;
  bool _isLoaded = false;
  bool _isSyncingServer = false; // Semáforo: evita syncs concurrentes con el servidor

  bool get isLoaded => _isLoaded;
  List<League> get allLeagues => _leagues.values.toList();
  String? get activeLeagueId => _activeLeagueId;

  League? get activeLeague {
    if (_activeLeagueId == null) return null;
    return _leagues[_activeLeagueId];
  }

  League? getLeague(String id) => _leagues[id];

  // --- Operaciones de Liga ---

  Future<League> createLeague({
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async {
    final cleanName = name.trim();
    final cleanPin = pin.trim();

    // ID amigable: ej. LIG-4821
    final randomDigits = (1000 + Random().nextInt(9000)).toString();
    final id = 'LIG-$randomDigits';

    var league = League(
      id: id,
      name: cleanName.isNotEmpty ? cleanName : 'Liga $randomDigits',
      pin: cleanPin.isNotEmpty ? cleanPin : '1234',
      createdAt: DateTime.now(),
      participants: initialParticipants,
    );

    // Inicializar estadísticas individuales para los participantes
    for (final p in initialParticipants) {
      final key = NameParser.removeDiacritics(p.trim().toLowerCase());
      league.players.putIfAbsent(key, () => PlayerStats(key: key, name: p));
    }

    // Intentar registrar en el servidor REST con timeout resiliente
    try {
      final serverLeague = await ApiClient().createLeague(
        id: league.id,
        name: league.name,
        pin: league.pin,
        initialParticipants: initialParticipants,
      );

      if (serverLeague != null) {
        league = serverLeague;
      }
    } catch (_) {}

    // Eliminar cualquier duplicado accidental previo con el mismo nombre y PIN sin partidas
    _leagues.removeWhere((key, existing) =>
        existing.id != league.id &&
        existing.name.trim().toLowerCase() == league.name.trim().toLowerCase() &&
        existing.pin.trim() == league.pin.trim() &&
        existing.matches.isEmpty);

    _leagues[league.id] = league;
    _activeLeagueId = league.id;
    await _saveData();
    notifyListeners();

    return league;
  }

  /// Intenta unirse a una liga existente usando su Nombre/ID y la Clave/PIN
  /// Busca primero en la memoria local y luego en el servidor REST
  Future<String?> joinLeague({
    required String nameOrId,
    required String pin,
  }) async {
    final search = NameParser.removeDiacritics(nameOrId.trim().toLowerCase());
    final enteredPin = pin.trim();

    final match = _leagues.values.firstWhere(
      (l) =>
          l.id.toLowerCase() == search ||
          NameParser.removeDiacritics(l.name.trim().toLowerCase()) == search,
      orElse: () => League(id: '', name: '', pin: '', createdAt: DateTime.now()),
    );

    if (match.id.isNotEmpty) {
      if (match.pin != enteredPin) {
        return 'La clave de acceso para "${match.name}" es incorrecta.';
      }
      _activeLeagueId = match.id;
      await _saveData();
      notifyListeners();
      return null; // éxito local
    }

    // Si no está en caché local, intentar consultar al servidor REST
    try {
      final res = await ApiClient().joinLeague(nameOrId: nameOrId, pin: pin);
      if (res['success'] == true && res['league'] is League) {
        final serverLeague = res['league'] as League;
        _leagues[serverLeague.id] = serverLeague;
        _activeLeagueId = serverLeague.id;
        await _saveData();
        notifyListeners();
        return null; // éxito servidor
      } else if (res['isConnectionError'] == true) {
        return 'No se encontró la liga "$nameOrId" en este dispositivo.\n(Tip: prueba buscando por su código exacto ej. LIG-9872)';
      } else if (res['error'] != null) {
        return res['error'].toString();
      }
    } catch (_) {}

    return 'No se encontró ninguna liga con el nombre o código ingresado.\n(Tip: verifica que esté bien escrito o usa el código ID)';
  }

  Future<void> setActiveLeague(String? leagueId) async {
    _activeLeagueId = leagueId;
    await _saveData();
    notifyListeners();
  }

  /// Elimina una liga del dispositivo y opcionalmente del servidor si se provee el PIN
  Future<String?> deleteLeague(String id, {String? pin, bool deleteOnServer = true}) async {
    if (deleteOnServer && pin != null && pin.trim().isNotEmpty) {
      final res = await ApiClient().deleteLeague(id, pin: pin.trim());
      if (res['success'] != true) {
        return res['error'] ?? 'Error al eliminar la liga en el servidor.';
      }
    }

    _leagues.remove(id);
    if (_activeLeagueId == id) {
      _activeLeagueId = _leagues.isNotEmpty ? _leagues.keys.first : null;
    }
    await _saveData();
    notifyListeners();
    return null; // éxito
  }

  Future<void> addParticipantToActiveLeague(String name) async {
    final league = activeLeague;
    if (league == null) return;
    league.addParticipant(name);
    await _saveData();
    notifyListeners();
  }

  Future<void> removeParticipantFromActiveLeague(String name) async {
    final league = activeLeague;
    if (league == null) return;
    league.removeParticipant(name);
    await _saveData();
    notifyListeners();
  }

  Future<void> recordMatchForActiveLeague(LeagueMatch match) async {
    final league = activeLeague;
    if (league == null) return;

    // 1. Guardar la partida localmente PRIMERO (operación síncrona en memoria)
    league.recordMatch(match);

    // 2. Persistir en SharedPreferences inmediatamente
    await _saveData();
    notifyListeners();

    // 3. Sincronizar con servidor en background (nunca bloquea ni sobreescribe datos locales)
    _syncMatchToServer(league, match);
  }

  /// Envía la partida al servidor en background. No bloquea ni reemplaza datos locales.
  Future<void> _syncMatchToServer(League league, LeagueMatch match) async {
    if (_isSyncingServer) return; // Ya hay un sync en curso
    _isSyncingServer = true;
    try {
      await ApiClient().recordMatch(
        leagueId: league.id,
        match: match,
        leagueName: league.name,
        pin: league.pin,
      );
    } catch (e) {
      debugPrint('Error enviando partida al servidor: $e');
    } finally {
      _isSyncingServer = false;
    }
  }

  /// Sincroniza la liga con el servidor usando merge inteligente.
  /// NUNCA sobreescribe datos locales con datos más antiguos del servidor.
  Future<bool> _syncLeagueWithServer(League? league) async {
    if (league == null) return false;
    if (_isSyncingServer) {
      debugPrint('Sync omitido: ya hay una sincronización en curso.');
      return false;
    }
    _isSyncingServer = true;
    try {
      League? serverLeague = await ApiClient().syncLeague(league);
      serverLeague ??= await ApiClient().fetchLeague(league.id);

      if (serverLeague != null) {
        // Merge inteligente: el servidor NUNCA puede eliminar partidas locales.
        // Solo agregamos partidas que están en el servidor pero no en local.
        final localMatchIds = league.matches.map((m) => m.id).toSet();
        bool mergedAny = false;
        for (final serverMatch in serverLeague.matches) {
          if (!localMatchIds.contains(serverMatch.id)) {
            // Insertar al inicio (más reciente primero) SIN llamar recordMatch()
            // para no duplicar estadísticas — la lista de matches es suficiente.
            league.matches.insert(0, serverMatch);
            mergedAny = true;
          }
        }
        // Actualizar la referencia local preservando los datos locales
        _leagues[league.id] = league;
        if (mergedAny) {
          await _saveData();
          notifyListeners();
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en sync con servidor: $e');
      return false;
    } finally {
      _isSyncingServer = false;
    }
  }

  Future<bool> syncActiveLeagueWithServer() async {
    final league = activeLeague;
    if (league == null) return false;
    return await _syncLeagueWithServer(league);
  }

  Future<void> syncAllLeaguesWithServer() async {
    for (final league in _leagues.values) {
      if (_isSyncingServer) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      final serverLeague = await ApiClient().syncLeague(league);
      if (serverLeague != null) {
        // Merge: solo agregar partidas del servidor que no estén en local
        final localIds = league.matches.map((m) => m.id).toSet();
        for (final sm in serverLeague.matches) {
          if (!localIds.contains(sm.id)) {
            league.matches.add(sm);
          }
        }
        _leagues[league.id] = league;
      }
    }
    await _saveData();
    notifyListeners();
  }

  // --- Rankings Globales y Mensuales (Agregado de todas las ligas del servidor) ---

  List<DateTime> getAvailableMonths({String? leagueId}) {
    final set = <String, DateTime>{};
    final sourceLeagues = leagueId != null
        ? (_leagues.containsKey(leagueId) ? [_leagues[leagueId]!] : <League>[])
        : _leagues.values;

    for (final league in sourceLeagues) {
      for (final m in league.matches) {
        final key = '${m.date.year}-${m.date.month.toString().padLeft(2, '0')}';
        if (!set.containsKey(key)) {
          set[key] = DateTime(m.date.year, m.date.month);
        }
      }
    }
    final list = set.values.toList();
    list.sort((a, b) => b.compareTo(a));
    return list;
  }

  List<TeamStats> getGlobalTeamsRanked({int? year, int? month}) {
    final Map<String, TeamStats> aggregate = {};

    for (final league in _leagues.values) {
      final filtered = (year == null || month == null)
          ? league.matches
          : league.matches.where((m) => m.date.year == year && m.date.month == month);

      if (filtered.isNotEmpty) {
        for (final m in filtered) {
          final key1 = NameParser.generateTeamKey(m.team1Members);
          final t1 = aggregate.putIfAbsent(
            key1,
            () => TeamStats(
              key: key1,
              displayName: m.team1DisplayName,
              members: List.from(m.team1Members),
            ),
          );
          t1.matchesPlayed += 1;
          t1.totalPoints += m.score1;
          if (m.winnerTeam == 1) t1.wins += 1;

          final key2 = NameParser.generateTeamKey(m.team2Members);
          final t2 = aggregate.putIfAbsent(
            key2,
            () => TeamStats(
              key: key2,
              displayName: m.team2DisplayName,
              members: List.from(m.team2Members),
            ),
          );
          t2.matchesPlayed += 1;
          t2.totalPoints += m.score2;
          if (m.winnerTeam == 2) t2.wins += 1;
        }
      } else if (year == null || month == null) {
        for (final team in league.teams.values) {
          final existing = aggregate[team.key];
          if (existing == null) {
            aggregate[team.key] = TeamStats(
              key: team.key,
              displayName: team.displayName,
              members: List.from(team.members),
              wins: team.wins,
              matchesPlayed: team.matchesPlayed,
              totalPoints: team.totalPoints,
            );
          } else {
            existing.wins += team.wins;
            existing.matchesPlayed += team.matchesPlayed;
            existing.totalPoints += team.totalPoints;
          }
        }
      }
    }

    final list = aggregate.values.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      final rateCmp = b.winRate.compareTo(a.winRate);
      if (rateCmp != 0) return rateCmp;
      return b.totalPoints.compareTo(a.totalPoints);
    });
    return list;
  }

  List<PlayerStats> getGlobalPlayersRanked({int? year, int? month}) {
    final Map<String, PlayerStats> aggregate = {};

    for (final league in _leagues.values) {
      final filtered = (year == null || month == null)
          ? league.matches
          : league.matches.where((m) => m.date.year == year && m.date.month == month);

      if (filtered.isNotEmpty) {
        for (final m in filtered) {
          for (final name in m.team1Members) {
            final key = NameParser.removeDiacritics(name.trim().toLowerCase());
            final p = aggregate.putIfAbsent(key, () => PlayerStats(key: key, name: name));
            p.matchesPlayed += 1;
            if (m.winnerTeam == 1) p.wins += 1;
          }

          for (final name in m.team2Members) {
            final key = NameParser.removeDiacritics(name.trim().toLowerCase());
            final p = aggregate.putIfAbsent(key, () => PlayerStats(key: key, name: name));
            p.matchesPlayed += 1;
            if (m.winnerTeam == 2) p.wins += 1;
          }
        }
      } else if (year == null || month == null) {
        for (final player in league.players.values) {
          final existing = aggregate[player.key];
          if (existing == null) {
            aggregate[player.key] = PlayerStats(
              key: player.key,
              name: player.name,
              wins: player.wins,
              matchesPlayed: player.matchesPlayed,
            );
          } else {
            existing.wins += player.wins;
            existing.matchesPlayed += player.matchesPlayed;
          }
        }
      }
    }

    final list = aggregate.values.toList();
    list.sort((a, b) {
      final winsCmp = b.wins.compareTo(a.wins);
      if (winsCmp != 0) return winsCmp;
      return b.winRate.compareTo(a.winRate);
    });
    return list;
  }

  // --- Persistencia con SharedPreferences ---

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeLeagueId = prefs.getString(_activeLeaguePrefKey);

      final jsonStr = prefs.getString(_leaguesPrefKey);
      if (jsonStr != null) {
        final decoded = jsonDecode(jsonStr) as List<dynamic>;
        _leagues.clear();
        for (final item in decoded) {
          final l = League.fromMap(item as Map<String, dynamic>);
          _leagues[l.id] = l;
        }

        // Limpieza automática de ligas duplicadas accidentales (mismo nombre y PIN con 0 partidas)
        final seen = <String, String>{};
        final toRemove = <String>[];
        for (final l in _leagues.values) {
          if (l.matches.isNotEmpty) continue;
          final key = '${l.name.trim().toLowerCase()}__${l.pin.trim()}';
          if (seen.containsKey(key)) {
            final prevId = seen[key]!;
            if (l.id == _activeLeagueId) {
              toRemove.add(prevId);
              seen[key] = l.id;
            } else {
              toRemove.add(l.id);
            }
          } else {
            seen[key] = l.id;
          }
        }
        for (final id in toRemove) {
          _leagues.remove(id);
        }
        // Limpiar ligas de prueba o demo del entorno de desarrollo
        final testKeys = _leagues.keys.where((id) {
          final l = _leagues[id]!;
          return id == 'LIG-1001' ||
              id == 'LIG-SYNC-TEST' ||
              id == 'LIG-4853' ||
              id == 'LIG-3887' ||
              id == 'LIG-1600' ||
              l.name == 'Liga de Campeones Dominó' ||
              l.name.contains('Prueba CI') ||
              l.name == 'Liga Sincronizada';
        }).toList();
        for (final k in testKeys) {
          _leagues.remove(k);
        }
        if (_activeLeagueId != null && !_leagues.containsKey(_activeLeagueId)) {
          _activeLeagueId = _leagues.isNotEmpty ? _leagues.keys.first : null;
        }
        if (toRemove.isNotEmpty || testKeys.isNotEmpty) {
          await _saveData();
        }
      }
    } catch (e) {
      debugPrint('Error loading leagues: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_activeLeagueId != null) {
        await prefs.setString(_activeLeaguePrefKey, _activeLeagueId!);
      } else {
        await prefs.remove(_activeLeaguePrefKey);
      }

      final leaguesList = _leagues.values.map((l) => l.toMap()).toList();
      await prefs.setString(_leaguesPrefKey, jsonEncode(leaguesList));
    } catch (e) {
      debugPrint('Error saving leagues: $e');
    }
  }
}
