import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../domain/repositories/league_repository.dart';
import '../../models/leaderboard_entry.dart';
import '../../models/league.dart';

export '../../domain/repositories/league_repository.dart' show RankingSnapshot;

typedef ServerRankingResult = RankingSnapshot;

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

  http.Client? _client;
  Zone? _clientZone;

  http.Client get _http {
    final current = Zone.current;
    if (_client != null && identical(_clientZone, current)) {
      return _client!;
    }
    final created = http.Client();
    _client = created;
    _clientZone = current;
    return created;
  }

  String _monthQueryString(int? year, int? month, {int? tzOffsetMinutes}) {
    final params = <String>[];
    if (year != null && month != null) {
      params.add('year=$year');
      params.add('month=$month');
    }
    if (tzOffsetMinutes != null) {
      params.add('tzOffsetMinutes=$tzOffsetMinutes');
    }
    if (params.isEmpty) return '';
    return '?${params.join('&')}';
  }

  List<DateTime> _parseAvailableMonths(dynamic raw) {
    if (raw is! List) return const [];
    final months = <DateTime>[];
    for (final entry in raw) {
      final parts = entry.toString().split('-');
      if (parts.length != 2) continue;
      final year = int.tryParse(parts[0]);
      final month = int.tryParse(parts[1]);
      if (year != null && month != null && month >= 1 && month <= 12) {
        months.add(DateTime(year, month));
      }
    }
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  Future<bool> isServerAvailable() async {
    try {
      final res =
          await _http.get(Uri.parse('$baseUrl/health')).timeout(requestTimeout);
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
      final res = await _http
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
      final res = await _http
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
      final res = await _http
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
      final res = await _http
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

  Future<List<String>?> addParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) async {
    try {
      final res = await _http
          .post(
            Uri.parse('$baseUrl/api/leagues/$leagueId/participants'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name.trim(),
              'pin': pin.trim(),
            }),
          )
          .timeout(requestTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> &&
            data['success'] == true &&
            data['participants'] is List) {
          return (data['participants'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiClient.addParticipant error: $e');
    }
    return null;
  }

  Future<List<String>?> removeParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) async {
    try {
      final encodedName = Uri.encodeComponent(name.trim());
      final res = await _http
          .delete(
            Uri.parse(
                '$baseUrl/api/leagues/$leagueId/participants/$encodedName'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'pin': pin.trim()}),
          )
          .timeout(requestTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> &&
            data['success'] == true &&
            data['participants'] is List) {
          return (data['participants'] as List<dynamic>)
              .map((e) => e.toString())
              .toList();
        }
      }
    } catch (e) {
      debugPrint('ApiClient.removeParticipant error: $e');
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

      final res = await _http
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

  Future<Map<String, dynamic>?> _fetchRankingJson(String path) async {
    try {
      final res =
          await _http.get(Uri.parse('$baseUrl$path')).timeout(requestTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is Map<String, dynamic> && data['success'] == true) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('ApiClient._fetchRankingJson($path) error: $e');
    }
    return null;
  }

  Future<List<TeamStats>?> fetchGlobalTeams({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async {
    final data = await _fetchRankingJson(
      '/api/rankings/global/teams${_monthQueryString(year, month, tzOffsetMinutes: tzOffsetMinutes)}',
    );
    if (data == null || data['teams'] is! List) return null;
    return (data['teams'] as List<dynamic>)
        .map((item) => TeamStats.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<PlayerStats>?> fetchGlobalPlayers({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async {
    final data = await _fetchRankingJson(
      '/api/rankings/global/players${_monthQueryString(year, month, tzOffsetMinutes: tzOffsetMinutes)}',
    );
    if (data == null || data['players'] is! List) return null;
    return (data['players'] as List<dynamic>)
        .map((item) => PlayerStats.fromMap(item as Map<String, dynamic>))
        .toList();
  }

  Future<ServerRankingResult?> fetchGlobalRankings({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async {
    final query =
        _monthQueryString(year, month, tzOffsetMinutes: tzOffsetMinutes);
    final responses = await Future.wait([
      _fetchRankingJson('/api/rankings/global/teams$query'),
      _fetchRankingJson('/api/rankings/global/players$query'),
    ]);

    final teamsJson = responses[0];
    final playersJson = responses[1];
    if (teamsJson == null || playersJson == null) return null;

    final rawTeams = teamsJson['teams'] as List<dynamic>? ?? const [];
    final rawPlayers = playersJson['players'] as List<dynamic>? ?? const [];

    return ServerRankingResult(
      teams: rawTeams
          .map((item) => TeamStats.fromMap(item as Map<String, dynamic>))
          .toList(),
      players: rawPlayers
          .map((item) => PlayerStats.fromMap(item as Map<String, dynamic>))
          .toList(),
      availableMonths: _parseAvailableMonths(teamsJson['availableMonths']),
    );
  }

  Future<ServerRankingResult?> fetchLeagueRankings(
    String leagueId, {
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async {
    final data = await _fetchRankingJson(
      '/api/rankings/league/$leagueId${_monthQueryString(year, month, tzOffsetMinutes: tzOffsetMinutes)}',
    );
    if (data == null) return null;

    final rawTeams = data['teams'] as List<dynamic>? ?? const [];
    final rawPlayers = data['players'] as List<dynamic>? ?? const [];

    return ServerRankingResult(
      teams: rawTeams
          .map((item) => TeamStats.fromMap(item as Map<String, dynamic>))
          .toList(),
      players: rawPlayers
          .map((item) => PlayerStats.fromMap(item as Map<String, dynamic>))
          .toList(),
      availableMonths: _parseAvailableMonths(data['availableMonths']),
    );
  }

  /// Devuelve `null` en error de red/servidor para diferenciarlo de una lista vacía.
  Future<List<Map<String, dynamic>>?> fetchServerLeagues() async {
    try {
      final res = await _http
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
    return null;
  }

  Future<Map<String, dynamic>> deleteLeague(String id,
      {required String pin}) async {
    final cleanPin = pin.trim();
    try {
      final res = await _http
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
