import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/leaderboard_repository.dart';
import '../../models/leaderboard_entry.dart';

class LeaderboardRepositoryImpl implements ILeaderboardRepository {
  static const String _teamsPrefKey = 'domino_leaderboard_teams_v1';
  static const String _playersPrefKey = 'domino_leaderboard_players_v1';

  @override
  Future<LocalLeaderboardState> loadLeaderboard() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final teams = <TeamStats>[];
      final players = <PlayerStats>[];

      final teamsJson = prefs.getString(_teamsPrefKey);
      if (teamsJson != null) {
        final decoded = jsonDecode(teamsJson) as List<dynamic>;
        for (final item in decoded) {
          teams.add(TeamStats.fromMap(item as Map<String, dynamic>));
        }
      }

      final playersJson = prefs.getString(_playersPrefKey);
      if (playersJson != null) {
        final decoded = jsonDecode(playersJson) as List<dynamic>;
        for (final item in decoded) {
          players.add(PlayerStats.fromMap(item as Map<String, dynamic>));
        }
      }

      return LocalLeaderboardState(teams: teams, players: players);
    } catch (e) {
      debugPrint('Error loading leaderboard: $e');
      return const LocalLeaderboardState(teams: [], players: []);
    }
  }

  @override
  Future<void> saveLeaderboard({
    required Iterable<TeamStats> teams,
    required Iterable<PlayerStats> players,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final teamsData = teams.map((t) => t.toMap()).toList();
      await prefs.setString(_teamsPrefKey, jsonEncode(teamsData));

      final playersData = players.map((p) => p.toMap()).toList();
      await prefs.setString(_playersPrefKey, jsonEncode(playersData));
    } catch (e) {
      debugPrint('Error saving leaderboard: $e');
    }
  }
}
