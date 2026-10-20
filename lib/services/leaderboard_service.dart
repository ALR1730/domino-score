import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/leaderboard_entry.dart';
import '../models/league.dart';
import 'ranking_calculator.dart';

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance = LeaderboardService._internal();
  factory LeaderboardService() => _instance;

  /// Completa cuando la carga inicial termina. Se espera en escrituras para
  /// evitar que un registro rápido pise (o sea pisado por) la carga de prefs.
  late final Future<void> _loadFuture;

  LeaderboardService._internal() {
    _loadFuture = loadData();
  }

  static const String _teamsPrefKey = 'domino_leaderboard_teams_v1';
  static const String _playersPrefKey = 'domino_leaderboard_players_v1';

  final Map<String, TeamStats> _teams = {};
  final Map<String, PlayerStats> _players = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<TeamStats> get teams => _teams.values.toList();
  List<PlayerStats> get players => _players.values.toList();

  List<TeamStats> get teamsRanked => RankingCalculator.sortTeams(_teams.values);

  List<PlayerStats> get playersRanked =>
      RankingCalculator.sortPlayers(_players.values);

  /// Registra una partida (casual o de liga) en la clasificación local de
  /// este dispositivo. Devuelve `false` si no se pudo registrar (equipos sin
  /// nombres válidos).
  Future<bool> recordMatch(LeagueMatch match) async {
    await _loadFuture; // esperar la carga inicial para no pisarla ni perder la partida

    if (NameParser.generateTeamKey(match.team1Members).isEmpty ||
        NameParser.generateTeamKey(match.team2Members).isEmpty) {
      return false;
    }

    RankingCalculator.aggregateTeamsInto(_teams, [match]);
    RankingCalculator.aggregatePlayersInto(_players, [match]);

    await _saveData();
    notifyListeners();
    return true;
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
    await _loadFuture;
    _teams.clear();
    _players.clear();
    await _saveData();
    notifyListeners();
  }
}
