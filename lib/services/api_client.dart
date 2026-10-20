import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/leaderboard_entry.dart';
import '../models/league.dart';

class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  static const String defaultBaseUrl =
      'https://domino-score-backend.onrender.com';

  /// Timeout único para todas las llamadas REST (antes 45s/20s/10s dispersos).
  static const Duration requestTimeout = Duration(seconds: 45);

  // URL fija para backend en la nube
  final String baseUrl = defaultBaseUrl;

  Future<bool> isServerAvailable() async {
    try {
      final res =
          await http.get(Uri.parse('$baseUrl/health')).timeout(requestTimeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<League?> createLeague({
    String? id,
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async {
    try {
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/leagues'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              if (id != null) 'id': id,
              'name': name,
              'pin': pin,
              'initialParticipants': initialParticipants,
            }),
          )
          .timeout(requestTimeout);
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
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/leagues/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(league.toMap()),
          )
          .timeout(requestTimeout);
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
      final res = await http
          .post(
            Uri.parse('$baseUrl/api/leagues/join'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'nameOrId': nameOrId, 'pin': pin}),
          )
          .timeout(requestTimeout);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {'success': true, 'league': League.fromMap(data['league'])};
      } else {
        return {
          'success': false,
          'error': data['error'] ?? 'Error al unirse a la liga'
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Servidor no disponible',
        'isConnectionError': true
      };
    }
  }

  Future<League?> fetchLeague(String id) async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/leagues/$id'))
          .timeout(requestTimeout);
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

      final res = await http
          .post(
            Uri.parse('$baseUrl/api/leagues/$leagueId/matches'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
      return res.statusCode == 201;
    } catch (e) {
      debugPrint('ApiClient.recordMatch error: $e');
      return false;
    }
  }

  Future<List<TeamStats>?> fetchGlobalTeams() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/api/rankings/global/teams'))
          .timeout(requestTimeout);
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
      final res = await http
          .get(Uri.parse('$baseUrl/api/rankings/global/players'))
          .timeout(requestTimeout);
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
      final res = await http
          .get(Uri.parse('$baseUrl/api/leagues'))
          .timeout(requestTimeout);
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

  Future<Map<String, dynamic>> deleteLeague(String id,
      {required String pin}) async {
    final cleanPin = pin.trim();
    try {
      // El PIN viaja solo en el body (el backend acepta body u query para
      // compatibilidad con APKs antiguas que aún envían ambos).
      final res = await http
          .delete(
            Uri.parse('$baseUrl/api/leagues/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': cleanPin}),
          )
          .timeout(requestTimeout);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        return {'success': true};
      }
      return {
        'success': false,
        'error': data['error'] ?? 'No se pudo eliminar la liga.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error de conexión al servidor: $e'};
    }
  }
}
