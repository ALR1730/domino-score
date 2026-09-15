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

  static const String defaultBaseUrl = 'https://domino-score-backend.onrender.com';
  static const String _prefKeyBaseUrl = 'domino_api_base_url_v2';

  // URL fija para backend en la nube
  String baseUrl = defaultBaseUrl;

  Future<void> loadSavedBaseUrl() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKeyBaseUrl);
      if (saved != null &&
          saved.trim().isNotEmpty &&
          saved.startsWith('https://') &&
          !saved.contains('127.0.0.1') &&
          !saved.contains('localhost')) {
        baseUrl = saved.trim();
      } else {
        baseUrl = defaultBaseUrl;
      }
    } catch (_) {
      baseUrl = defaultBaseUrl;
    }
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

  Future<bool> isServerAvailable({Duration timeout = const Duration(seconds: 45)}) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>> checkHealth({Duration timeout = const Duration(seconds: 45)}) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(timeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        return {
          'online': true,
          'database': data['database'] ?? 'unknown',
          'features': data['features'] ?? [],
        };
      }
    } catch (_) {}
    return {'online': false, 'database': 'none'};
  }

  Future<League?> createLeague({
    String? id,
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          if (id != null) 'id': id,
          'name': name,
          'pin': pin,
          'initialParticipants': initialParticipants,
        }),
      ).timeout(const Duration(seconds: 45));
      if (res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return League.fromMap(data['league']);
      }
    } catch (e) {
      debugPrint('ApiClient.createLeague error: $e');
    }
    return null;
  }

  Future<League?> syncLeague(League league) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues/sync'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(league.toMap()),
      ).timeout(const Duration(seconds: 45));
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        if (data['league'] != null) {
          return League.fromMap(data['league']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.syncLeague error: $e');
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
      ).timeout(const Duration(seconds: 45));
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
      final res = await http.get(Uri.parse('$baseUrl/api/leagues/$id')).timeout(const Duration(seconds: 45));
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
    String? leagueName,
    String? pin,
  }) async {
    try {
      final payload = match.toMap();
      if (leagueName != null) payload['leagueName'] = leagueName;
      if (pin != null) payload['pin'] = pin;

      final res = await http.post(
        Uri.parse('$baseUrl/api/leagues/$leagueId/matches'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 45));
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('ApiClient.recordMatch error: $e');
      return false;
    }
  }

  Future<List<TeamStats>?> fetchGlobalTeams() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/rankings/global/teams')).timeout(const Duration(seconds: 45));
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
      final res = await http.get(Uri.parse('$baseUrl/api/rankings/global/players')).timeout(const Duration(seconds: 45));
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

  Future<List<Map<String, dynamic>>> fetchServerLeagues() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/leagues')).timeout(const Duration(seconds: 45));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['leagues'] is List) {
          return List<Map<String, dynamic>>.from(data['leagues']);
        }
      }
    } catch (e) {
      debugPrint('ApiClient.fetchServerLeagues error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> deleteLeague(String id, {required String pin}) async {
    final cleanPin = pin.trim();
    try {
      // 1. Intento principal: DELETE con body y query param por compatibilidad
      http.Response res = await http.delete(
        Uri.parse('$baseUrl/api/leagues/$id?pin=${Uri.encodeComponent(cleanPin)}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'pin': cleanPin}),
      ).timeout(const Duration(seconds: 20));

      // 2. Si responde 404 Endpoint no encontrado, intentar fallback POST
      if (res.statusCode == 404) {
        try {
          final testData = jsonDecode(res.body);
          if (testData['error'] == 'Endpoint no encontrado') {
            res = await http.post(
              Uri.parse('$baseUrl/api/leagues/$id/delete'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'pin': cleanPin}),
            ).timeout(const Duration(seconds: 10));
          }
        } catch (_) {}
      }

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      } else {
        String err = data['error'] ?? 'No se pudo eliminar la liga.';
        if (err == 'Endpoint no encontrado') {
          err = 'El servidor Render aún está ejecutando la versión previa. En tu dashboard de Render haz clic en "Manual Deploy" -> "Deploy latest commit".';
        }
        return {'success': false, 'error': err};
      }
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión al servidor: $e'};
    }
  }
}
