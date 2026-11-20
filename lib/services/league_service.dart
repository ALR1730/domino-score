import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/leaderboard_entry.dart';
import '../models/league.dart';
import 'api_client.dart';
import 'ranking_calculator.dart';

class LeagueService extends ChangeNotifier {
  static final LeagueService _instance = LeagueService._internal();
  factory LeagueService() => _instance;
  LeagueService._internal() {
    _loadFuture = loadData();
  }

  static const String _leaguesPrefKey = 'domino_leagues_registry_v1';
  static const String _activeLeaguePrefKey = 'domino_active_league_id_v1';

  final Map<String, League> _leagues = {};
  final Set<String> _pendingSyncLeagueIds = {};
  late Future<void> _loadFuture;
  String? _activeLeagueId;
  bool _isLoaded = false;
  bool _isSyncingServer =
      false; // Semáforo: evita syncs concurrentes con el servidor

  bool get isLoaded => _isLoaded;
  List<League> get allLeagues => _leagues.values.toList();
  String? get activeLeagueId => _activeLeagueId;

  League? get activeLeague {
    if (_activeLeagueId == null) return null;
    return _leagues[_activeLeagueId];
  }

  League? getLeague(String id) => _leagues[id];

  Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await _loadFuture;
    }
  }

  /// Genera un PIN de 4 dígitos usando RNG criptográfico, evitando `'1234'`.
  static String generateSecurePin() {
    final rng = Random.secure();
    var pin = '1234';
    while (pin == '1234') {
      pin = (1000 + rng.nextInt(9000)).toString();
    }
    return pin;
  }

  /// Solo para tests: vacía el estado en memoria y recarga desde prefs.
  @visibleForTesting
  Future<void> resetForTesting() async {
    _leagues.clear();
    _pendingSyncLeagueIds.clear();
    _activeLeagueId = null;
    _isLoaded = false;
    _isSyncingServer = false;
    _loadFuture = loadData();
    await _loadFuture;
  }

  // --- Operaciones de Liga ---

  Future<League> createLeague({
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async {
    await ensureLoaded();

    final cleanName = name.trim();
    final cleanPin = pin.trim();

    // ID amigable: ej. LIG-4821
    final randomDigits = (1000 + Random.secure().nextInt(9000)).toString();
    final id = 'LIG-$randomDigits';

    // PIN aleatorio seguro si no se especifica: nunca "1234" adivinable.
    final resolvedPin = cleanPin.isNotEmpty ? cleanPin : generateSecurePin();

    final cleanParticipants = <String>[];
    final seenKeys = <String>{};
    for (final raw in initialParticipants) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) continue;
      final key = NameParser.removeDiacritics(trimmed.toLowerCase());
      if (key.isEmpty || !seenKeys.add(key)) continue;
      cleanParticipants.add(trimmed);
    }

    var league = League(
      id: id,
      name: cleanName.isNotEmpty ? cleanName : 'Liga $randomDigits',
      pin: resolvedPin,
      createdAt: DateTime.now(),
      participants: cleanParticipants,
    );

    // Inicializar estadísticas individuales para los participantes
    for (final p in cleanParticipants) {
      final key = NameParser.removeDiacritics(p.toLowerCase());
      league.players.putIfAbsent(key, () => PlayerStats(key: key, name: p));
    }

    // Intentar registrar en el servidor REST con timeout resiliente
    try {
      final serverLeague = await ApiClient().createLeague(
        id: league.id,
        name: league.name,
        pin: league.pin,
        initialParticipants: cleanParticipants,
      );

      if (serverLeague != null) {
        // El servidor nunca devuelve el PIN en el objeto `league`: conservar
        // el que eligió el usuario en este dispositivo.
        league = serverLeague;
        league.pin = resolvedPin;
      }
    } catch (_) {}

    // Eliminar cualquier duplicado accidental previo con el mismo nombre y PIN sin partidas
    _leagues.removeWhere((key, existing) =>
        existing.id != league.id &&
        existing.name.trim().toLowerCase() ==
            league.name.trim().toLowerCase() &&
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
    await ensureLoaded();

    final search = NameParser.removeDiacritics(nameOrId.trim().toLowerCase());
    final enteredPin = pin.trim();

    final match = _leagues.values.firstWhere(
      (l) =>
          l.id.toLowerCase() == search ||
          NameParser.removeDiacritics(l.name.trim().toLowerCase()) == search,
      orElse: () =>
          League(id: '', name: '', pin: '', createdAt: DateTime.now()),
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
    await ensureLoaded();
    _activeLeagueId = leagueId;
    await _saveData();
    notifyListeners();
  }

  /// Elimina una liga del dispositivo y opcionalmente del servidor si se provee el PIN
  Future<String?> deleteLeague(String id,
      {String? pin, bool deleteOnServer = true}) async {
    await ensureLoaded();

    if (deleteOnServer && pin != null && pin.trim().isNotEmpty) {
      final res = await ApiClient().deleteLeague(id, pin: pin.trim());
      if (res['success'] != true) {
        return res['error'] ?? 'Error al eliminar la liga en el servidor.';
      }
    }

    _leagues.remove(id);
    _pendingSyncLeagueIds.remove(id);
    if (_activeLeagueId == id) {
      _activeLeagueId = _leagues.isNotEmpty ? _leagues.keys.first : null;
    }
    await _saveData();
    notifyListeners();
    return null; // éxito
  }

  Future<void> addParticipantToLeague(String leagueId, String name) async {
    await ensureLoaded();
    final league = _leagues[leagueId];
    if (league == null) return;
    league.addParticipant(name);
    await _saveData();
    notifyListeners();
  }

  Future<void> addParticipantToActiveLeague(String name) async {
    await ensureLoaded();
    final id = _activeLeagueId;
    if (id == null) return;
    await addParticipantToLeague(id, name);
  }

  Future<void> removeParticipantFromActiveLeague(String name) async {
    await ensureLoaded();
    final league = activeLeague;
    if (league == null) return;
    league.removeParticipant(name);
    await _saveData();
    notifyListeners();
  }

  /// Registra [match] en la liga con id [leagueId] — capturada al inicio de
  /// la partida — y no en "la liga activa", que pudo cambiar durante el juego.
  /// Devuelve `false` si la liga ya no existe en el dispositivo.
  Future<bool> recordMatchToLeague(String leagueId, LeagueMatch match) async {
    await ensureLoaded();
    final league = _leagues[leagueId];
    if (league == null) return false;

    // 1. Guardar la partida localmente PRIMERO (operación síncrona en memoria)
    league.recordMatch(match);

    // 2. Persistir en SharedPreferences inmediatamente
    await _saveData();
    notifyListeners();

    // 3. Sincronizar con servidor en background (nunca bloquea ni sobreescribe datos locales)
    unawaited(_syncMatchToServer(league, match));
    return true;
  }

  void _drainPendingSync() {
    while (_pendingSyncLeagueIds.isNotEmpty) {
      final nextId = _pendingSyncLeagueIds.first;
      _pendingSyncLeagueIds.remove(nextId);
      final nextLeague = _leagues[nextId];
      if (nextLeague != null) {
        unawaited(_syncLeagueWithServer(nextLeague));
        return;
      }
    }
  }

  bool _mergeServerMatchesInto(League local, League server) {
    final localMatchIds = local.matches.map((m) => m.id).toSet();
    var mergedAny = false;
    for (final serverMatch in server.matches) {
      if (!localMatchIds.contains(serverMatch.id)) {
        local.matches.insert(0, serverMatch);
        mergedAny = true;
      }
    }
    if (mergedAny) {
      local.sortMatchesByDate();
    }
    return mergedAny;
  }

  /// Envía la partida al servidor en background; encola si ya hay sync en curso.
  Future<void> _syncMatchToServer(League league, LeagueMatch match) async {
    if (_isSyncingServer) {
      _pendingSyncLeagueIds.add(league.id);
      return;
    }
    _isSyncingServer = true;
    var sent = false;
    try {
      sent = await ApiClient().recordMatch(
        leagueId: league.id,
        match: match,
        leagueName: league.name,
        pin: league.pin,
      );
      if (!sent) {
        _pendingSyncLeagueIds.add(league.id);
      }
    } catch (e) {
      _pendingSyncLeagueIds.add(league.id);
      debugPrint('Error enviando partida al servidor: $e');
    } finally {
      _isSyncingServer = false;
      if (sent) _drainPendingSync();
    }
  }

  /// Sincroniza la liga con el servidor usando merge inteligente.
  /// NUNCA sobreescribe datos locales con datos más antiguos del servidor.
  Future<bool> _syncLeagueWithServer(League? league) async {
    if (league == null) return false;
    if (_isSyncingServer) {
      _pendingSyncLeagueIds.add(league.id);
      debugPrint('Sync diferido: ya hay una sincronización en curso.');
      return false;
    }
    _isSyncingServer = true;
    var ok = false;
    try {
      League? serverLeague = await ApiClient().syncLeague(league);
      serverLeague ??= await ApiClient().fetchLeague(league.id);

      if (serverLeague != null) {
        final mergedAny = _mergeServerMatchesInto(league, serverLeague);
        _leagues[league.id] = league;
        if (mergedAny) {
          await _saveData();
          notifyListeners();
        }
        ok = true;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error en sync con servidor: $e');
      return false;
    } finally {
      _isSyncingServer = false;
      if (ok) _drainPendingSync();
    }
  }

  Future<bool> syncActiveLeagueWithServer() async {
    await ensureLoaded();
    final league = activeLeague;
    if (league == null) return false;
    return await _syncLeagueWithServer(league);
  }

  Future<bool> syncAllLeaguesWithServer() async {
    await ensureLoaded();
    if (_isSyncingServer) return false;
    _isSyncingServer = true;
    var allSucceeded = true;
    try {
      final snapshot = List<League>.of(_leagues.values);
      var mergedAny = false;
      for (final league in snapshot) {
        final serverLeague = await ApiClient().syncLeague(league);
        if (serverLeague == null) {
          allSucceeded = false;
          continue;
        }
        if (_mergeServerMatchesInto(league, serverLeague)) {
          mergedAny = true;
        }
        _leagues[league.id] = league;
        _pendingSyncLeagueIds.remove(league.id);
      }
      if (mergedAny) {
        await _saveData();
        notifyListeners();
      }
      return allSucceeded;
    } catch (e) {
      debugPrint('Error en syncAllLeaguesWithServer: $e');
      return false;
    } finally {
      _isSyncingServer = false;
      if (allSucceeded) _drainPendingSync();
    }
  }

  // --- Rankings Globales y Mensuales (Agregado de todas las ligas locales) ---

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
    final aggregate = <String, TeamStats>{};

    for (final league in _leagues.values) {
      final filtered = league.matchesForMonth(year, month);
      if (filtered.isNotEmpty) {
        RankingCalculator.aggregateTeamsInto(aggregate, filtered);
      } else if (year == null || month == null) {
        // Liga sin partidas: fusionar sus estadísticas ya agregadas
        RankingCalculator.mergeTeamsInto(aggregate, league.teams);
      }
    }

    return RankingCalculator.sortTeams(aggregate.values);
  }

  List<PlayerStats> getGlobalPlayersRanked({int? year, int? month}) {
    final aggregate = <String, PlayerStats>{};

    for (final league in _leagues.values) {
      final filtered = league.matchesForMonth(year, month);
      if (filtered.isNotEmpty) {
        RankingCalculator.aggregatePlayersInto(aggregate, filtered);
      } else if (year == null || month == null) {
        RankingCalculator.mergePlayersInto(aggregate, league.players);
      }
    }

    return RankingCalculator.sortPlayers(aggregate.values);
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
          // Normaliza el orden persistido: más reciente primero.
          l.sortMatchesByDate();
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
        if (_activeLeagueId != null && !_leagues.containsKey(_activeLeagueId)) {
          _activeLeagueId = _leagues.isNotEmpty ? _leagues.keys.first : null;
        }
        if (toRemove.isNotEmpty) {
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
