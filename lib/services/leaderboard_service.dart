import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leaderboard_entry.dart';
import 'api_client.dart';

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;
  LeaderboardService._internal() {
    loadData();
  }

  static const String _teamsPrefKey = 'domino_leaderboard_teams_v1';
  static const String _playersPrefKey = 'domino_leaderboard_players_v1';

  final Map<String, TeamStats> _teams = {};
  final Map<String, PlayerStats> _players = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<TeamStats> get teams => _teams.values.toList();
  List<PlayerStats> get players => _players.values.toList();

  List<TeamStats> get teamsRanked {
    final list = _teams.values.toList();
    list.sort((a, b) {
      // 1. Victorias
      final winsCompare = b.wins.compareTo(a.wins);
      if (winsCompare != 0) return winsCompare;
      // 2. Win rate
      final rateCompare = b.winRate.compareTo(a.winRate);
      if (rateCompare != 0) return rateCompare;
      // 3. Puntos totales acumulados
      return b.totalPoints.compareTo(a.totalPoints);
    });
    return list;
  }

  List<PlayerStats> get playersRanked {
    final list = _players.values.toList();
    list.sort((a, b) {
      final winsCompare = b.wins.compareTo(a.wins);
      if (winsCompare != 0) return winsCompare;
      return b.winRate.compareTo(a.winRate);
    });
    return list;
  }

  Future<void> recordMatch({
    required String rawTeam1,
    required String rawTeam2,
    required int score1,
    required int score2,
    required int winnerTeam, // 1 or 2
  }) async {
    // 1. Extraer y normalizar miembros de cada equipo
    final members1 = NameParser.extractMembers(rawTeam1);
    final members2 = NameParser.extractMembers(rawTeam2);

    final key1 = NameParser.generateTeamKey(members1);
    final key2 = NameParser.generateTeamKey(members2);

    if (key1.isEmpty || key2.isEmpty) return;

    final display1 = NameParser.formatTeamDisplayName(members1);
    final display2 = NameParser.formatTeamDisplayName(members2);

    // 2. Actualizar o crear Equipo 1
    final team1 = _teams.putIfAbsent(
      key1,
      () => TeamStats(
        key: key1,
        displayName: display1,
        members: members1,
      ),
    );
    team1.matchesPlayed += 1;
    team1.totalPoints += score1;
    if (winnerTeam == 1) {
      team1.wins += 1;
    }

    // 3. Actualizar o crear Equipo 2
    final team2 = _teams.putIfAbsent(
      key2,
      () => TeamStats(
        key: key2,
        displayName: display2,
        members: members2,
      ),
    );
    team2.matchesPlayed += 1;
    team2.totalPoints += score2;
    if (winnerTeam == 2) {
      team2.wins += 1;
    }

    // 4. Actualizar estadísticas individuales de cada jugador
    _updatePlayersFromTeam(members1, isWinner: winnerTeam == 1);
    _updatePlayersFromTeam(members2, isWinner: winnerTeam == 2);

    await _saveData();
    notifyListeners();

    // Sincronizar en segundo plano con el ranking global del servidor REST
    ApiClient().recordCasualMatch(
      rawTeam1: rawTeam1,
      rawTeam2: rawTeam2,
      score1: score1,
      score2: score2,
      winnerTeam: winnerTeam,
    ).catchError((_) => false);
  }

  void _updatePlayersFromTeam(List<String> members, {required bool isWinner}) {
    for (final member in members) {
      final key = NameParser.removeDiacritics(member.trim().toLowerCase());
      if (key.isEmpty) continue;

      final player = _players.putIfAbsent(
        key,
        () => PlayerStats(
          key: key,
          name: member,
        ),
      );
      player.matchesPlayed += 1;
      if (isWinner) {
        player.wins += 1;
      }
    }
  }

  Future<void> loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final teamsJson = prefs.getString(_teamsPrefKey);
      if (teamsJson != null) {
        final decoded = jsonDecode(teamsJson) as List<dynamic>;
        _teams.clear();
        for (final item in decoded) {
          final stat = TeamStats.fromMap(item as Map<String, dynamic>);
          _teams[stat.key] = stat;
        }
      }

      final playersJson = prefs.getString(_playersPrefKey);
      if (playersJson != null) {
        final decoded = jsonDecode(playersJson) as List<dynamic>;
        _players.clear();
        for (final item in decoded) {
          final stat = PlayerStats.fromMap(item as Map<String, dynamic>);
          _players[stat.key] = stat;
        }
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final teamsData = _teams.values.map((t) => t.toMap()).toList();
      await prefs.setString(_teamsPrefKey, jsonEncode(teamsData));

      final playersData = _players.values.map((p) => p.toMap()).toList();
      await prefs.setString(_playersPrefKey, jsonEncode(playersData));
    } catch (e) {
      debugPrint('Error saving leaderboard: $e');
    }
  }

  Future<void> resetLeaderboard() async {
    _teams.clear();
    _players.clear();
    await _saveData();
    notifyListeners();
  }
}
