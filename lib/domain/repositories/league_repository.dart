import '../../models/leaderboard_entry.dart';
import '../../models/league.dart';

class RankingSnapshot {
  final List<TeamStats> teams;
  final List<PlayerStats> players;
  final List<DateTime> availableMonths;

  const RankingSnapshot({
    required this.teams,
    required this.players,
    required this.availableMonths,
  });
}

class LocalLeaguesState {
  final List<League> leagues;
  final String? activeLeagueId;

  const LocalLeaguesState({
    required this.leagues,
    required this.activeLeagueId,
  });
}

class JoinRemoteResult {
  final League? league;
  final String? error;
  final bool isConnectionError;

  const JoinRemoteResult({
    this.league,
    this.error,
    this.isConnectionError = false,
  });
}

class DeleteRemoteResult {
  final bool success;
  final String? error;

  const DeleteRemoteResult({
    required this.success,
    required this.error,
  });
}

abstract interface class ILeagueRepository {
  Future<LocalLeaguesState> loadLocalState();

  Future<void> saveLocalState({
    required Iterable<League> leagues,
    required String? activeLeagueId,
  });

  Future<bool> isServerAvailable();

  Future<List<Map<String, dynamic>>?> fetchServerLeagues();

  Future<League?> createRemoteLeague({
    String? id,
    required String name,
    required String pin,
    required List<String> initialParticipants,
  });

  Future<League?> syncRemoteLeague(League league);

  Future<League?> fetchRemoteLeague(String id);

  Future<JoinRemoteResult> joinRemoteLeague({
    required String nameOrId,
    required String pin,
  });

  Future<DeleteRemoteResult> deleteRemoteLeague(
    String id, {
    required String pin,
  });

  Future<List<String>?> addRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  });

  Future<List<String>?> removeRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  });

  Future<bool> recordRemoteMatch({
    required String leagueId,
    required LeagueMatch match,
    String? leagueName,
    String? pin,
  });

  Future<RankingSnapshot?> fetchGlobalRankings({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  });

  Future<RankingSnapshot?> fetchLeagueRankings(
    String leagueId, {
    int? year,
    int? month,
    int? tzOffsetMinutes,
  });
}
