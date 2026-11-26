import 'package:flutter/foundation.dart';

import '../domain/repositories/leaderboard_repository.dart';
import '../infrastructure/repositories/leaderboard_repository_impl.dart';
import '../models/leaderboard_entry.dart';
import '../models/league.dart';
import 'ranking_calculator.dart';

class LeaderboardService extends ChangeNotifier {
  static final LeaderboardService _instance =
      LeaderboardService.withRepository(LeaderboardRepositoryImpl());
  factory LeaderboardService() => _instance;

  LeaderboardService.withRepository(this._repository) {
    _loadFuture = loadData();
  }

  factory LeaderboardService.isolated({ILeaderboardRepository? repository}) {
    return LeaderboardService.withRepository(
      repository ?? LeaderboardRepositoryImpl(),
    );
  }

  final ILeaderboardRepository _repository;

  /// Completa cuando la carga inicial termina. Se espera en escrituras para
  /// evitar que un registro rápido pise (o sea pisado por) la carga de prefs.
  late final Future<void> _loadFuture;

  final Map<String, TeamStats> _teams = {};
  final Map<String, PlayerStats> _players = {};
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<TeamStats> get teams => _teams.values.toList();
  List<PlayerStats> get players => _players.values.toList();

  List<TeamStats> get teamsRanked => RankingCalculator.sortTeams(_teams.values);

  List<PlayerStats> get playersRanked =>
      RankingCalculator.sortPlayers(_players.values);

  Future<void> ensureLoaded() async {
    if (!_isLoaded) {
      await _loadFuture;
    }
  }

  /// Registra una partida (casual o de liga) en la clasificación local de
  /// este dispositivo. Devuelve `false` si no se pudo registrar (equipos sin
  /// nombres válidos).
  Future<bool> recordMatch(LeagueMatch match) async {
    await ensureLoaded();

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
      final state = await _repository.loadLeaderboard();
      _teams.clear();
      for (final stat in state.teams) {
        _teams[stat.key] = stat;
      }

      _players.clear();
      for (final stat in state.players) {
        _players[stat.key] = stat;
      }
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> _saveData() async {
    await _repository.saveLeaderboard(
      teams: _teams.values,
      players: _players.values,
    );
  }

  Future<void> resetLeaderboard() async {
    await ensureLoaded();
    _teams.clear();
    _players.clear();
    await _saveData();
    notifyListeners();
  }
}
