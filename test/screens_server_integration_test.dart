import 'dart:convert';

import 'package:domino_score/screens/league/global_ranking_screen.dart';
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
    final client = MockClient((request) async {
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
    }, () => client);
  });
}
