import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leaderboard_entry.dart';
import '../models/league.dart';
import 'ranking_calculator.dart';

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

  List<TeamStats> get teamsRanked =>
      RankingCalculator.sortTeams(_teams.values);

  List<PlayerStats> get playersRanked =>
      RankingCalculator.sortPlayers(_players.values);

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

    if (NameParser.generateTeamKey(members1).isEmpty ||
        NameParser.generateTeamKey(members2).isEmpty) {
      return;
    }

    // 2. Agregar la partida con la implementación compartida
    final match = LeagueMatch(
      id: 'local_${DateTime.now().microsecondsSinceEpoch}',
      date: DateTime.now(),
      team1DisplayName: NameParser.formatTeamDisplayName(members1),
      team2DisplayName: NameParser.formatTeamDisplayName(members2),
      team1Members: members1,
      team2Members: members2,
      score1: score1,
      score2: score2,
      winnerTeam: winnerTeam,
    );
    RankingCalculator.aggregateTeamsInto(_teams, [match]);
    RankingCalculator.aggregatePlayersInto(_players, [match]);

    await _saveData();
    notifyListeners();
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
