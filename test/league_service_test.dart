import 'dart:async';
import 'dart:convert';

import 'package:domino_score/models/league.dart';
import 'package:domino_score/services/api_client.dart';
import 'package:domino_score/services/league_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Clave de prefs de `LeagueService` (debe coincidir con el servicio).
const String _leaguesKey = 'domino_leagues_registry_v1';
const String _activeKey = 'domino_active_league_id_v1';

/// Construye la app con las ligas indicadas ya "persistidas" en prefs.
///
/// Nota: el singleton de [LeagueService] no expone un reset, así que cada test
/// parte de una app recién creada (ver `setUp` con `setMockInitialValues`).
http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

String _seedLeague({
  required String id,
  required String name,
  String pin = '1234',
  List<Map<String, dynamic>> matches = const [],
}) {
  final map = {
    'id': id,
    'name': name,
    'pin': pin,
    'createdAt': DateTime(2026, 1, 1).toIso8601String(),
    'participants': <String>[],
    'teams': <String, dynamic>{},
    'players': <String, dynamic>{},
    'matches': matches,
  };
  return jsonEncode([map]);
}

LeagueMatch _match(
        {required String id, String date = '2026-03-15T12:00:00.000Z'}) =>
    LeagueMatch(
      id: id,
      date: DateTime.parse(date),
      team1DisplayName: 'Ana & Luis',
      team2DisplayName: 'Pedro & Marcos',
      team1Members: ['Ana', 'Luis'],
      team2Members: ['Pedro', 'Marcos'],
      score1: 200,
      score2: 150,
      winnerTeam: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = LeagueService();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await service.resetForTesting();
  });

  group('LeagueService.createLeague', () {
    test('crea local y activa la liga, con ID LIG-####', () async {
      final league = await runWithFakeServer(
        (requests) async => _json({
          'success': true,
          'league': {'id': 'x'}
        }),
        () => service.createLeague(
          name: 'Liga Amigos',
          pin: '4321',
          initialParticipants: ['Ana', 'Luis'],
        ),
      );

      expect(league.id, startsWith('LIG-'));
      expect(league.name, 'Liga Amigos');
      expect(service.activeLeagueId, league.id);
      expect(service.getLeague(league.id), isNotNull);
      // Las estadísticas individuales se inicializan para los participantes.
      expect(league.players.length, 2);
    });

    test('genera un PIN aleatorio de 4 dígitos si no se especifica', () async {
      final league = await service.createLeague(
        name: 'Sin Pin',
        pin: '   ',
        initialParticipants: [],
      );
      expect(league.pin, matches(RegExp(r'^\d{4}$')));
      expect(league.pin, isNot('1234'),
          reason: 'nunca el viejo PIN adivinable');
    });

    test('conserva el PIN local aunque el servidor no lo devuelva', () async {
      final league = await runWithFakeServer(
        (request) async => _json({
          'success': true,
          // El backend nunca incluye el PIN dentro del objeto league.
          'league': {'id': 'LIG-1234', 'name': 'Con Servidor'},
          'pin': '4321',
        }, status: 201),
        () => service.createLeague(
          name: 'Con Servidor',
          pin: '4321',
          initialParticipants: [],
        ),
      );

      expect(league.pin, '4321');
      expect(service.getLeague('LIG-1234')!.pin, '4321');
    });
  });

  group('LeagueService.joinLeague', () {
    test('encuentra la liga local con el PIN correcto', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-1000', name: 'Vecinos', pin: '9999'),
      });
      await service.resetForTesting();

      final error = await service.joinLeague(nameOrId: 'Vecinos', pin: '9999');
      expect(error, isNull);
      expect(service.activeLeagueId, 'LIG-1000');
    });

    test('rechaza un PIN incorrecto en la liga local', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-1000', name: 'Vecinos', pin: '9999'),
      });
      await service.resetForTesting();

      final error = await service.joinLeague(nameOrId: 'LIG-1000', pin: '0000');
      expect(error, contains('incorrecta'));
    });

    test('busca en el servidor cuando la liga no está en el dispositivo',
        () async {
      final error = await runWithFakeServer(
        (request) async {
          if (request.url.path.endsWith('/join')) {
            return _json({
              'success': true,
              'league': {
                'id': 'LIG-7777',
                'name': 'Remota',
                'pin': '5555',
                'createdAt': DateTime(2026, 2, 1).toIso8601String(),
                'participants': ['Hugo'],
                'teams': <String, dynamic>{},
                'players': <String, dynamic>{},
                'matches': <dynamic>[],
              },
            });
          }
          return _json({'success': false, 'error': 'inesperado'}, status: 500);
        },
        () => service.joinLeague(nameOrId: 'Remota', pin: '5555'),
      );

      expect(error, isNull);
      expect(service.getLeague('LIG-7777'), isNotNull);
      expect(service.activeLeagueId, 'LIG-7777');
    });

    test('informa error de conexión si el servidor no responde', () async {
      final error = await runWithFakeServer(
        (request) async => throw const SocketExceptionStub(),
        () => service.joinLeague(nameOrId: 'Inexistente', pin: '1111'),
      );

      expect(error, contains('este dispositivo'));
    });
  });

  group('LeagueService.recordMatchToLeague', () {
    test('registra en la liga indicada aunque no sea la activa', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-1000', name: 'A'),
        _activeKey: 'LIG-1000',
      });
      await service.resetForTesting();

      // Liga distinta (no activa) a la que se le registra la partida.
      final other = await runWithFakeServer(
        (requests) async => _json({'success': true, 'match': {}}),
        () => service
            .createLeague(name: 'B', pin: '2222', initialParticipants: []),
      );
      await service.setActiveLeague('LIG-1000');

      final ok = await runWithFakeServer(
        (requests) async => _json({'success': true, 'match': {}}),
        () => service.recordMatchToLeague(other.id, _match(id: 'm-1')),
      );

      expect(ok, isTrue);
      expect(service.getLeague(other.id)!.matches.length, 1,
          reason: 'la partida debe ir a la liga indicada');
      expect(service.getLeague('LIG-1000')!.matches, isEmpty,
          reason: 'la liga activa no debe recibir la partida');
    });

    test('devuelve false si la liga ya no existe', () async {
      final ok =
          await service.recordMatchToLeague('LIG-NO-EXISTE', _match(id: 'm-2'));
      expect(ok, isFalse);
    });
  });

  group('LeagueService.deleteLeague', () {
    test('elimina localmente si deleteOnServer es false', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-1000', name: 'A'),
        _activeKey: 'LIG-1000',
      });
      await service.resetForTesting();

      final error =
          await service.deleteLeague('LIG-1000', deleteOnServer: false);
      expect(error, isNull);
      expect(service.getLeague('LIG-1000'), isNull);
      expect(service.activeLeagueId, isNull);
    });

    test('no elimina localmente si el servidor rechaza el PIN', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-1000', name: 'A', pin: '9999'),
        _activeKey: 'LIG-1000',
      });
      await service.resetForTesting();

      final error = await runWithFakeServer(
        (request) async => _json({
          'success': false,
          'error': 'PIN incorrecto para eliminar la liga.'
        }, status: 401),
        () => service.deleteLeague('LIG-1000', pin: '0000'),
      );

      expect(error, contains('PIN incorrecto'));
      expect(service.getLeague('LIG-1000'), isNotNull,
          reason: 'si el servidor falla, la liga local se conserva');
    });
  });

  group('LeagueService.syncLeagueWithServer (merge)', () {
    test('agrega partidas del servidor sin duplicar las locales', () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(
          id: 'LIG-1000',
          name: 'A',
          matches: [
            {
              'id': 'm-local',
              'date': '2026-03-10T12:00:00.000Z',
              'team1DisplayName': 'Ana & Luis',
              'team2DisplayName': 'Pedro & Marcos',
              'team1Members': ['Ana', 'Luis'],
              'team2Members': ['Pedro', 'Marcos'],
              'score1': 200,
              'score2': 150,
              'winnerTeam': 1,
            }
          ],
        ),
        _activeKey: 'LIG-1000',
      });
      await service.resetForTesting();

      await runWithFakeServer(
        (request) async => _json({
          'success': true,
          'league': {
            'id': 'LIG-1000',
            'name': 'A',
            'pin': '1234',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'participants': <String>[],
            'teams': <String, dynamic>{},
            'players': <String, dynamic>{},
            'matches': [
              {
                'id': 'm-local', // ya existe en local: no se duplica
                'date': '2026-03-10T12:00:00.000Z',
                'team1DisplayName': 'Ana & Luis',
                'team2DisplayName': 'Pedro & Marcos',
                'team1Members': ['Ana', 'Luis'],
                'team2Members': ['Pedro', 'Marcos'],
                'score1': 200,
                'score2': 150,
                'winnerTeam': 1,
              },
              {
                'id': 'm-server', // nueva: debe agregarse
                'date': '2026-03-20T12:00:00.000Z',
                'team1DisplayName': 'Ana & Luis',
                'team2DisplayName': 'Pedro & Marcos',
                'team1Members': ['Ana', 'Luis'],
                'team2Members': ['Pedro', 'Marcos'],
                'score1': 100,
                'score2': 80,
                'winnerTeam': 2,
              },
            ],
          },
        }),
        () => service.syncActiveLeagueWithServer(),
      );

      final league = service.getLeague('LIG-1000')!;
      expect(league.matches.length, 2);
      expect(league.matches.map((m) => m.id).toSet(), {'m-local', 'm-server'});
    });
  });

  group('LeagueService.rankings', () {
    test('agrega equipos de varias ligas y sus meses disponibles', () async {
      final seeded = jsonEncode([
        jsonDecode(_seedLeague(id: 'A', name: 'A', matches: [
          {
            'id': 'a1',
            'date': '2026-03-15T12:00:00.000Z',
            'team1DisplayName': 'Ana & Luis',
            'team2DisplayName': 'Pedro & Marcos',
            'team1Members': ['Ana', 'Luis'],
            'team2Members': ['Pedro', 'Marcos'],
            'score1': 200,
            'score2': 150,
            'winnerTeam': 1,
          }
        ]))[0],
        jsonDecode(_seedLeague(id: 'B', name: 'B', matches: [
          {
            'id': 'b1',
            'date': '2026-04-02T12:00:00.000Z',
            'team1DisplayName': 'Sara & Tom',
            'team2DisplayName': 'Ana & Luis',
            'team1Members': ['Sara', 'Tom'],
            'team2Members': ['Ana', 'Luis'],
            'score1': 210,
            'score2': 100,
            'winnerTeam': 1,
          }
        ]))[0],
      ]);
      SharedPreferences.setMockInitialValues({_leaguesKey: seeded});
      await service.resetForTesting();

      final teams = service.getGlobalTeamsRanked();
      expect(teams.map((t) => t.key),
          containsAll(['ana_luis', 'marcos_pedro', 'sara_tom']));

      final march = service.getGlobalTeamsRanked(year: 2026, month: 3);
      expect(
          march.map((t) => t.key), containsAll(['ana_luis', 'marcos_pedro']));
      expect(
        march.firstWhere((t) => t.key == 'ana_luis').wins,
        1,
      );

      final months = service.getAvailableMonths();
      expect(months.length, 2);
      expect(months.first.month, 4,
          reason: 'ordenados del más reciente al más antiguo');
    });

    test(
        'el fallback usa estadísticas agregadas cuando la liga no tiene partidas',
        () async {
      final league = jsonDecode(_seedLeague(id: 'A', name: 'A'))[0]
          as Map<String, dynamic>;
      league['teams'] = {
        'ana_luis': {
          'key': 'ana_luis',
          'displayName': 'Ana & Luis',
          'members': ['Ana', 'Luis'],
          'wins': 7,
          'matchesPlayed': 9,
          'totalPoints': 900,
        }
      };
      SharedPreferences.setMockInitialValues({
        _leaguesKey: jsonEncode([league])
      });
      await service.resetForTesting();

      final teams = service.getGlobalTeamsRanked();
      expect(teams.length, 1);
      expect(teams.first.wins, 7);
    });
  });

  group('LeagueService — Fase 2 seguridad y sincronización', () {
    test('generateSecurePin devuelve 4 dígitos y nunca 1234', () {
      for (int i = 0; i < 200; i++) {
        final pin = LeagueService.generateSecurePin();
        expect(pin, matches(RegExp(r'^\d{4}$')));
        expect(pin, isNot('1234'));
      }
    });

    test('addParticipantToLeague deduplica nombres sin tildes (José / Jose)',
        () async {
      final league = await runWithFakeServer(
        (req) async => _json({
          'success': true,
          'league': {'id': 'LIG-9001', 'name': 'Tildes'}
        }, status: 201),
        () => service.createLeague(
          name: 'Tildes',
          pin: '5678',
          initialParticipants: [],
        ),
      );

      await service.addParticipantToLeague(league.id, 'José');
      await service.addParticipantToLeague(league.id, 'Jose');

      expect(service.getLeague(league.id)!.participants, ['José']);
    });

    test('League.fromMap tolera scores double y sin pin devuelve cadena vacía',
        () {
      final parsed = League.fromMap({
        'id': 'LIG-2222',
        'name': 'Legada',
        'createdAt': '2026-03-01T12:00:00.000Z',
        'matches': [
          {
            'id': 'm-dbl',
            'date': '2026-03-01T12:00:00.000Z',
            'team1DisplayName': 'A & B',
            'team2DisplayName': 'C & D',
            'team1Members': ['A', 'B'],
            'team2Members': ['C', 'D'],
            'score1': 200.0,
            'score2': 150.0,
            'winnerTeam': 1.0,
          },
        ],
      });

      expect(parsed.pin, '');
      expect(parsed.matches.first.score1, 200);
      expect(parsed.matches.first.score2, 150);
      expect(parsed.matches.first.winnerTeam, 1);
    });

    test(
        'recordMatchToLeague encola si hay un sync en curso y sincroniza luego',
        () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-Q1', name: 'Cola', pin: '4321'),
        _activeKey: 'LIG-Q1',
      });
      await service.resetForTesting();

      final releaseSync = Completer<void>();
      final syncedPayloads = <String>[];
      var firstSync = true;

      await runWithFakeServer((request) async {
        syncedPayloads.add(request.body);
        if (firstSync) {
          firstSync = false;
          await releaseSync.future;
        }
        return _json({
          'success': true,
          'league': {
            'id': 'LIG-Q1',
            'name': 'Cola',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'participants': <String>[],
            'teams': <String, dynamic>{},
            'players': <String, dynamic>{},
            'matches': <dynamic>[],
          },
        });
      }, () async {
        final inFlight = service.syncActiveLeagueWithServer();
        await Future<void>.delayed(Duration.zero);

        await service.recordMatchToLeague('LIG-Q1', _match(id: 'm-queued'));

        releaseSync.complete();
        await inFlight;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });

      expect(
        syncedPayloads.any((body) => body.contains('m-queued')),
        isTrue,
        reason: 'la partida encolada debe sincronizarse al liberarse el lock',
      );
    });
  });

  group('LeagueService y ApiClient — Fase 3', () {
    test('ApiClient reutiliza una única instancia http.Client por zona',
        () async {
      var factoryCalls = 0;
      await http.runWithClient(() async {
        final ok1 = await ApiClient().isServerAvailable();
        final ok2 = await ApiClient().isServerAvailable();
        expect(ok1, isTrue);
        expect(ok2, isTrue);
      }, () {
        factoryCalls += 1;
        return MockClient((_) async => _json({'status': 'ok'}));
      });

      expect(factoryCalls, 1);
    });

    test('addParticipantToLeague envía POST con PIN y tolera fallo de red',
        () async {
      SharedPreferences.setMockInitialValues({
        _leaguesKey: _seedLeague(id: 'LIG-P1', name: 'Liga P', pin: '4321'),
        _activeKey: 'LIG-P1',
      });
      await service.resetForTesting();

      final requests = <http.Request>[];
      await runWithFakeServer((req) async {
        requests.add(req);
        return _json({
          'success': true,
          'participants': ['Ana'],
        });
      }, () async {
        await service.addParticipantToLeague('LIG-P1', 'Ana');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(requests.length, 1);
      expect(requests.first.method, 'POST');
      expect(requests.first.url.path, '/api/leagues/LIG-P1/participants');
      expect(
        jsonDecode(requests.first.body),
        {'name': 'Ana', 'pin': '4321'},
      );
      expect(service.getLeague('LIG-P1')!.participants, contains('Ana'));

      // Tolerancia offline: no lanza excepción y conserva el participante local.
      await runWithFakeServer(
        (req) async => throw const SocketExceptionStub(),
        () async {
          await service.addParticipantToLeague('LIG-P1', 'Beto');
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
      );
      expect(service.getLeague('LIG-P1')!.participants,
          containsAll(['Ana', 'Beto']));
    });

    test(
        'removeParticipantFromActiveLeague envía DELETE codificado con PIN y tolera offline',
        () async {
      final seeded = jsonDecode(
        _seedLeague(id: 'LIG-P2', name: 'Liga Del', pin: '7890'),
      ) as List<dynamic>;
      (seeded.first as Map<String, dynamic>)['participants'] = [
        '50% Juan',
        'Pedro',
      ];
      SharedPreferences.setMockInitialValues({
        _leaguesKey: jsonEncode(seeded),
        _activeKey: 'LIG-P2',
      });
      await service.resetForTesting();

      final requests = <http.Request>[];
      await runWithFakeServer((req) async {
        requests.add(req);
        return _json({
          'success': true,
          'participants': ['Pedro'],
        });
      }, () async {
        await service.removeParticipantFromActiveLeague('50% Juan');
        await Future<void>.delayed(const Duration(milliseconds: 20));
      });

      expect(requests.length, 1);
      expect(requests.first.method, 'DELETE');
      expect(
        requests.first.url.path,
        '/api/leagues/LIG-P2/participants/50%25%20Juan',
      );
      expect(jsonDecode(requests.first.body), {'pin': '7890'});
      expect(service.getLeague('LIG-P2')!.participants, ['Pedro']);

      // Tolerancia offline al remover otro participante.
      await runWithFakeServer(
        (req) async => throw const SocketExceptionStub(),
        () async {
          await service.removeParticipantFromLeague('LIG-P2', 'Pedro');
          await Future<void>.delayed(const Duration(milliseconds: 20));
        },
      );
      expect(service.getLeague('LIG-P2')!.participants, isEmpty);
    });

    test(
        'syncActiveLeagueWithServer fusiona participantes y nombre sin pisar locales ni PIN',
        () async {
      final seeded = jsonDecode(
        _seedLeague(id: 'LIG-M1', name: 'Nombre Viejo', pin: '5544'),
      ) as List<dynamic>;
      (seeded.first as Map<String, dynamic>)['participants'] = [
        'José',
        'Solo Local',
      ];
      SharedPreferences.setMockInitialValues({
        _leaguesKey: jsonEncode(seeded),
        _activeKey: 'LIG-M1',
      });
      await service.resetForTesting();

      await runWithFakeServer(
        (req) async => _json({
          'success': true,
          'league': {
            'id': 'LIG-M1',
            'name': 'Nombre Actualizado',
            'createdAt': DateTime(2026, 1, 1).toIso8601String(),
            'participants': ['Jose', 'Desde Servidor'],
            'teams': <String, dynamic>{},
            'players': <String, dynamic>{},
            'matches': <dynamic>[],
          },
        }),
        () => service.syncActiveLeagueWithServer(),
      );

      final updated = service.getLeague('LIG-M1')!;
      expect(updated.name, 'Nombre Actualizado');
      expect(updated.pin, '5544');
      expect(updated.participants, ['José', 'Solo Local', 'Desde Servidor']);
    });
  });
}

// ---------------------------------------------------------------------------
// Utilidad: ejecuta [body] con un cliente HTTP falso inyectado por zona.
// (Equivalente a `http.runWithClient`, pero con un MockClient.)
// ---------------------------------------------------------------------------
Future<T> runWithFakeServer<T>(
  Future<http.Response> Function(http.Request request) handler,
  Future<T> Function() body,
) {
  final client = MockClient(handler);
  return http.runWithClient(() async {
    try {
      return await body();
    } finally {
      client.close();
    }
  }, () => client);
}

/// Excepción simple para simular un servidor caído sin depender de dart:io.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
  @override
  String toString() => 'SocketException: conexión rechazada';
}
