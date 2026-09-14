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

  bool get isLoaded => _isLoaded;
  List<League> get allLeagues => _leagues.values.toList();
  String? get activeLeagueId => _activeLeagueId;

  League? get activeLeague {
    if (_activeLeagueId == null) return null;
    return _leagues[_activeLeagueId];
  }

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

    final league = League(
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

    _leagues[league.id] = league;
    _activeLeagueId = league.id;
    await _saveData();
    notifyListeners();

    // Sincronizar en segundo plano con el servidor REST si está disponible
    ApiClient().createLeague(
      name: league.name,
      pin: league.pin,
      initialParticipants: initialParticipants,
    ).then((serverLeague) {
      if (serverLeague != null && serverLeague.id != league.id) {
        // En caso de que el backend haya asignado su propio ID
        _leagues[serverLeague.id] = serverLeague;
        _saveData();
      }
    }).catchError((_) {});

    return league;
  }

  /// Intenta unirse a una liga existente usando su Nombre/ID y la Clave/PIN
  /// Busca primero en la memoria local y luego en el servidor REST
  Future<String?> joinLeague({
    required String nameOrId,
    required String pin,
  }) async {
    final search = nameOrId.trim().toLowerCase();
    final enteredPin = pin.trim();

    final match = _leagues.values.firstWhere(
      (l) => l.id.toLowerCase() == search || l.name.trim().toLowerCase() == search,
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

    // Si no está en caché local, consultar al servidor REST
    try {
      final res = await ApiClient().joinLeague(nameOrId: nameOrId, pin: pin);
      if (res['success'] == true && res['league'] is League) {
        final serverLeague = res['league'] as League;
        _leagues[serverLeague.id] = serverLeague;
        _activeLeagueId = serverLeague.id;
        await _saveData();
        notifyListeners();
        return null; // éxito servidor
      } else if (res['error'] != null) {
        return res['error'].toString();
      }
    } catch (_) {}

    return 'No se encontró ninguna liga con el nombre o código ingresado.';
  }

  Future<void> setActiveLeague(String? leagueId) async {
    _activeLeagueId = leagueId;
    await _saveData();
    notifyListeners();
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
    league.recordMatch(match);
    await _saveData();
    notifyListeners();

    // Sincronizar en segundo plano con el servidor REST
    ApiClient().recordMatch(leagueId: league.id, match: match).catchError((_) => false);
  }

  // --- Rankings Globales (Agregado de todas las ligas del servidor) ---

  List<TeamStats> getGlobalTeamsRanked() {
    final Map<String, TeamStats> aggregate = {};

    for (final league in _leagues.values) {
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

  List<PlayerStats> getGlobalPlayersRanked() {
    final Map<String, PlayerStats> aggregate = {};

    for (final league in _leagues.values) {
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
      }

      // Si no hay ligas, inicializar con una de demostración
      if (_leagues.isEmpty) {
        final demo = League(
          id: 'LIG-1001',
          name: 'Liga de Campeones Dominó',
          pin: '7777',
          createdAt: DateTime.now().subtract(const Duration(days: 7)),
          participants: ['Carlos', 'Juan', 'Pedro', 'Luis', 'Andrés', 'Marcos'],
        );
        _leagues[demo.id] = demo;
        _activeLeagueId = demo.id;
        await _saveData();
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
