import '../../models/leaderboard_entry.dart';

class LocalLeaderboardState {
  final List<TeamStats> teams;
  final List<PlayerStats> players;

  const LocalLeaderboardState({
    required this.teams,
    required this.players,
  });
}

abstract interface class ILeaderboardRepository {
  Future<LocalLeaderboardState> loadLeaderboard();

  Future<void> saveLeaderboard({
    required Iterable<TeamStats> teams,
    required Iterable<PlayerStats> players,
  });
}
