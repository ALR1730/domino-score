import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/league_repository.dart';
import '../../models/league.dart';
import '../network/api_client.dart';

class LeagueRepositoryImpl implements ILeagueRepository {
  static const String _leaguesPrefKey = 'domino_leagues_registry_v1';
  static const String _activeLeaguePrefKey = 'domino_active_league_id_v1';

  final ApiClient _apiClient;

  LeagueRepositoryImpl({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  @override
  Future<LocalLeaguesState> loadLocalState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final activeLeagueId = prefs.getString(_activeLeaguePrefKey);
      final jsonStr = prefs.getString(_leaguesPrefKey);

      if (jsonStr == null) {
        return LocalLeaguesState(
          leagues: const [],
          activeLeagueId: activeLeagueId,
        );
      }

      final decoded = jsonDecode(jsonStr) as List<dynamic>;
      final leagues = <League>[];
      for (final item in decoded) {
        final league = League.fromMap(item as Map<String, dynamic>);
        league.sortMatchesByDate();
        leagues.add(league);
      }

      return LocalLeaguesState(
        leagues: leagues,
        activeLeagueId: activeLeagueId,
      );
    } catch (e) {
      debugPrint('Error loading leagues: $e');
      return const LocalLeaguesState(leagues: [], activeLeagueId: null);
    }
  }

  @override
  Future<void> saveLocalState({
    required Iterable<League> leagues,
    required String? activeLeagueId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (activeLeagueId != null) {
        await prefs.setString(_activeLeaguePrefKey, activeLeagueId);
      } else {
        await prefs.remove(_activeLeaguePrefKey);
      }

      final leaguesList = leagues.map((l) => l.toMap()).toList();
      await prefs.setString(_leaguesPrefKey, jsonEncode(leaguesList));
    } catch (e) {
      debugPrint('Error saving leagues: $e');
    }
  }

  @override
  Future<bool> isServerAvailable() => _apiClient.isServerAvailable();

  @override
  Future<List<Map<String, dynamic>>?> fetchServerLeagues() =>
      _apiClient.fetchServerLeagues();

  @override
  Future<League?> createRemoteLeague({
    String? id,
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) {
    return _apiClient.createLeague(
      id: id,
      name: name,
      pin: pin,
      initialParticipants: initialParticipants,
    );
  }

  @override
  Future<League?> syncRemoteLeague(League league) =>
      _apiClient.syncLeague(league);

  @override
  Future<League?> fetchRemoteLeague(String id) => _apiClient.fetchLeague(id);

  @override
  Future<JoinRemoteResult> joinRemoteLeague({
    required String nameOrId,
    required String pin,
  }) async {
    final res = await _apiClient.joinLeague(nameOrId: nameOrId, pin: pin);
    return JoinRemoteResult(
      league: res['league'] is League ? res['league'] as League : null,
      error: res['error']?.toString(),
      isConnectionError: res['isConnectionError'] == true,
    );
  }

  @override
  Future<DeleteRemoteResult> deleteRemoteLeague(
    String id, {
    required String pin,
  }) async {
    final res = await _apiClient.deleteLeague(id, pin: pin);
    return DeleteRemoteResult(
      success: res['success'] == true,
      error: res['error']?.toString(),
    );
  }

  @override
  Future<List<String>?> addRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) {
    return _apiClient.addParticipant(leagueId: leagueId, name: name, pin: pin);
  }

  @override
  Future<List<String>?> removeRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) {
    return _apiClient.removeParticipant(
      leagueId: leagueId,
      name: name,
      pin: pin,
    );
  }

  @override
  Future<bool> recordRemoteMatch({
    required String leagueId,
    required LeagueMatch match,
    String? leagueName,
    String? pin,
  }) {
    return _apiClient.recordMatch(
      leagueId: leagueId,
      match: match,
      leagueName: leagueName,
      pin: pin,
    );
  }

  @override
  Future<RankingSnapshot?> fetchGlobalRankings({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) {
    return _apiClient.fetchGlobalRankings(
      year: year,
      month: month,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }

  @override
  Future<RankingSnapshot?> fetchLeagueRankings(
    String leagueId, {
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) {
    return _apiClient.fetchLeagueRankings(
      leagueId,
      year: year,
      month: month,
      tzOffsetMinutes: tzOffsetMinutes,
    );
  }
}
