import 'dart:convert';

import 'package:domino_score/screens/league/global_ranking_screen.dart';
import 'package:domino_score/screens/league/league_home_screen.dart';
import 'package:domino_score/screens/league/league_manager_screen.dart';
import 'package:domino_score/services/league_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

http.Response _json(Object body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json'});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LeagueService().resetForTesting();
  });

  testWidgets(
      'LeagueManagerScreen muestra estado de error con Reintentar cuando falla la red',
      (WidgetTester tester) async {
    final client = MockClient((request) async {
      throw Exception('Sin conexión');
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LeagueManagerScreen()));
      await tester.pumpAndSettle();

      await tester.tap(
        find.descendant(
          of: find.byType(TabBar),
          matching: find.textContaining('En el Servidor'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('No se pudieron cargar las ligas del servidor.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);
    }, () => client);
  });

  testWidgets(
      'GlobalRankingScreen carga y muestra rankings reales del servidor aunque no haya ligas locales',
      (WidgetTester tester) async {
    final requestedUrls = <Uri>[];
    final client = MockClient((request) async {
      requestedUrls.add(request.url);
      if (request.url.path.endsWith('/api/rankings/global/teams')) {
        return _json({
          'success': true,
          'teams': [
            {
              'key': 'ana_luis',
              'displayName': 'Ana & Luis',
              'members': ['Ana', 'Luis'],
              'wins': 3,
              'matchesPlayed': 4,
              'totalPoints': 620,
            },
          ],
          'availableMonths': ['2026-10'],
        });
      }
      if (request.url.path.endsWith('/api/rankings/global/players')) {
        return _json({
          'success': true,
          'players': [
            {
              'key': 'ana',
              'name': 'Ana',
              'wins': 3,
              'matchesPlayed': 4,
            },
          ],
          'availableMonths': ['2026-10'],
        });
      }
      return _json({'success': false}, status: 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: GlobalRankingScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Ana & Luis'), findsOneWidget);
      expect(requestedUrls, isNotEmpty);
      expect(
        requestedUrls
            .every((uri) => uri.queryParameters.containsKey('tzOffsetMinutes')),
        isTrue,
      );
    }, () => client);
  });

  testWidgets(
      'LeagueHomeScreen no desborda con nombres largos en móvil ni muestra Render',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final seededLeague = [
      {
        'id': 'LIG-OVF1',
        'name': 'Liga Con Nombre Bastante Largo En Cabecera',
        'pin': '4321',
        'createdAt': DateTime(2026, 3, 1).toIso8601String(),
        'participants': [
          'Participante Con Un Nombre Extremadamente Largo Para Probar Overflow',
          'Otro Jugador De Nombre Largo',
        ],
        'teams': <String, dynamic>{},
        'players': <String, dynamic>{},
        'matches': [
          {
            'id': 'm-ovf-1',
            'date': '2026-03-15T12:00:00.000Z',
            'team1DisplayName': 'Alejandro Maximiliano & Bartolomeo Constancio',
            'team2DisplayName': 'Esteban Sebastián & Francisco Javier De León',
            'team1Members': ['Alejandro Maximiliano', 'Bartolomeo Constancio'],
            'team2Members': ['Esteban Sebastián', 'Francisco Javier De León'],
            'score1': 205,
            'score2': 185,
            'winnerTeam': 1,
          },
        ],
      }
    ];
    SharedPreferences.setMockInitialValues({
      'domino_leagues_registry_v1': jsonEncode(seededLeague),
      'domino_active_league_id_v1': 'LIG-OVF1',
    });
    await LeagueService().resetForTesting();

    final client = MockClient((request) async {
      if (request.url.path == '/health') {
        return _json({'status': 'ok'});
      }
      if (request.url.path == '/api/leagues/sync') {
        return _json({'success': true, 'league': seededLeague.first});
      }
      return _json({'success': false}, status: 404);
    });

    await http.runWithClient(() async {
      await tester.pumpWidget(const MaterialApp(home: LeagueHomeScreen()));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('Participantes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.textContaining('Partidas'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.textContaining('Render'), findsNothing);
    }, () => client);
  });
}
