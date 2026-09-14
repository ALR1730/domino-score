import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/leaderboard_entry.dart';
import '../models/league.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal() {
    loadSavedBaseUrl();
  }

  static const String _prefKeyBaseUrl = 'domino_api_base_url_v1';

  // URL configurable para backend local o en la nube (ej: Render, Railway o VPS)
  String baseUrl = 'http://127.0.0.1:3000';

  Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null && saved.trim().isNotEmpty) {
        baseUrl = saved.trim();
      }
    } catch (_) {}
  }

  Future<void> updateBaseUrl(String newUrl) async {
    baseUrl = newUrl.trim();
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyBaseUrl, baseUrl);
    } catch (_) {}
  }

  Future<bool> isServerAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 2));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<League?> createLeague({
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'pin': pin,
          'initialParticipants': initialParticipants,
        }),
      );
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return League.fromMap(data['league']);
      }
    } catch (e) {
      debugPrint('ApiClient.createLeague error: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> joinLeague({
    required String nameOrId,
    required String pin,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues/join'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'nameOrId': nameOrId, 'pin': pin}),
      ).timeout(const Duration(seconds: 3));
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'league': League.fromMap(data['league'])};
      } else {
        return {'success': false, 'error': data['error'] ?? 'Error al unirse a la liga'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Servidor no disponible', 'isConnectionError': true};
    }
  }

  Future<League?> fetchLeague(String id) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/leagues/$id'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return League.fromMap(data['league']);
      }
    } catch (e) {
      debugPrint('ApiClient.fetchLeague error: $e');
    }
    return null;
  }

  Future<bool> recordMatch({
    required String leagueId,
    required LeagueMatch match,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues/$leagueId/matches'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(match.toMap()),
      );
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('ApiClient.recordMatch error: $e');
      return false;
    }
  }

  Future<List<TeamStats>?> fetchGlobalTeams() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/rankings/global/teams'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['teams'] as List<dynamic>;
        return list.map((item) => TeamStats.fromMap(item)).toList();
      }
    } catch (e) {
      debugPrint('ApiClient.fetchGlobalTeams error: $e');
    }
    return null;
  }

  Future<List<PlayerStats>?> fetchGlobalPlayers() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/rankings/global/players'));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = data['players'] as List<dynamic>;
        return list.map((item) => PlayerStats.fromMap(item)).toList();
      }
    } catch (e) {
      debugPrint('ApiClient.fetchGlobalPlayers error: $e');
    }
    return null;
  }
}
