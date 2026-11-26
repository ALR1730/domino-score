import 'package:domino_score/models/league.dart';
import 'package:domino_score/widgets/league/league_matches_history_tab.dart';
import 'package:domino_score/widgets/league/league_participants_tab.dart';
import 'package:domino_score/widgets/league/local_leagues_tab.dart';
import 'package:domino_score/widgets/league/month_filter_bar.dart';
import 'package:domino_score/widgets/league/ranking_podium.dart';
import 'package:domino_score/widgets/league/server_leagues_tab.dart';
import 'package:domino_score/widgets/league_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      home: Scaffold(body: child),
    );
  }

  group('RankingPodium', () {
    testWidgets('oculta el podio cuando hay menos de 2 entradas', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          const RankingPodium(
            entries: [PodiumEntry(name: 'Solo Uno', wins: 4)],
          ),
        ),
      );

      expect(find.text('Solo Uno'), findsNothing);
    });

    testWidgets('renderiza correctamente con 2 y 3 entradas', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RankingPodium(
            entries: [
              PodiumEntry(name: 'Alfa', wins: 10),
              PodiumEntry(name: 'Beta', wins: 7),
            ],
          ),
        ),
      );

      expect(find.text('Alfa'), findsOneWidget);
      expect(find.text('Beta'), findsOneWidget);
      expect(find.text('10 Vic'), findsOneWidget);
      expect(find.text('7 Vic'), findsOneWidget);

      await tester.pumpWidget(
        wrap(
          const RankingPodium(
            entries: [
              PodiumEntry(name: 'Alfa', wins: 10),
              PodiumEntry(name: 'Beta', wins: 7),
              PodiumEntry(name: 'Gamma', wins: 4),
            ],
          ),
        ),
      );

      expect(find.text('Gamma'), findsOneWidget);
      expect(find.text('4 Vic'), findsOneWidget);
    });
  });

  group('MonthFilterBar y showMonthPickerSheet', () {
    testWidgets('muestra mes formateado y dispara navegación', (tester) async {
      var prevCalls = 0;
      var nextCalls = 0;
      var pickerCalls = 0;

      final availableMonths = [DateTime(2026, 11), DateTime(2026, 10)];

      await tester.pumpWidget(
        wrap(
          MonthFilterBar(
            selectedMonth: DateTime(2026, 11),
            availableMonths: availableMonths,
            onPrevMonth: () => prevCalls++,
            onNextMonth: () => nextCalls++,
            onOpenPicker: () => pickerCalls++,
          ),
        ),
      );

      expect(find.text(formatMonthYear(DateTime(2026, 11))), findsOneWidget);

      await tester.tap(find.byTooltip('Mes anterior'));
      await tester.tap(find.byTooltip('Mes siguiente'));
      await tester.tap(find.text('Noviembre 2026'));
      await tester.pump();

      expect(prevCalls, 1);
      expect(nextCalls, 1);
      expect(pickerCalls, 1);
    });

    testWidgets('showMonthPickerSheet selecciona un mes de la lista', (
      tester,
    ) async {
      DateTime? picked = DateTime(2026, 11);
      final months = [DateTime(2026, 11), DateTime(2026, 10)];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showMonthPickerSheet(
                    context,
                    selectedMonth: picked,
                    availableMonths: months,
                    onSelectMonth: (m) => picked = m,
                  );
                },
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Octubre 2026'));
      await tester.pumpAndSettle();

      expect(picked, DateTime(2026, 10));
    });
  });

  group('Tabs de LeagueHomeScreen en viewport compacto 360x640', () {
    testWidgets(
      'LeagueParticipantsTab evita overflow y dispara callbacks con nombres largos',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const longName =
            'Participante Con Un Nombre Extremadamente Largo Para Probar Overflow';
        String? removedName;
        var addTapped = false;

        await tester.pumpWidget(
          wrap(
            LeagueParticipantsTab(
              participants: const [longName],
              onAddParticipant: () => addTapped = true,
              onRemoveParticipant: (name) => removedName = name,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('participant_$longName')),
          findsOneWidget,
        );

        await tester.tap(find.text('Agregar'));
        await tester.tap(find.byIcon(Icons.close));
        await tester.pump();

        expect(addTapped, isTrue);
        expect(removedName, longName);
      },
    );

    testWidgets(
      'LeagueMatchesHistoryTab renderiza nombres largos sin overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final matches = [
          LeagueMatch(
            id: 'm1',
            date: DateTime(2026, 11, 20),
            team1DisplayName: 'Equipo Uno Con Nombre Sumamente Extenso y Largo',
            team2DisplayName: 'Equipo Dos También Con Un Nombre Bastante Largo',
            team1Members: const ['Jugador A Largo', 'Jugador B Largo'],
            team2Members: const ['Jugador C Largo', 'Jugador D Largo'],
            score1: 205,
            score2: 140,
            winnerTeam: 1,
          ),
        ];

        await tester
            .pumpWidget(wrap(LeagueMatchesHistoryTab(matches: matches)));

        expect(tester.takeException(), isNull);
        expect(find.textContaining('205 pts'), findsOneWidget);
        expect(find.textContaining('140 pts'), findsOneWidget);
      },
    );
  });

  group('Tabs de LeagueManagerScreen', () {
    testWidgets('LocalLeaguesTab muestra estado vacío y card activa', (
      tester,
    ) async {
      var createTapped = false;
      League? activated;
      League? deleted;

      await tester.pumpWidget(
        wrap(
          LocalLeaguesTab(
            localLeagues: const [],
            activeId: null,
            onCreateLeague: () => createTapped = true,
            onActivateLeague: (l) => activated = l,
            onDeleteLeague: (l) => deleted = l,
          ),
        ),
      );

      expect(find.text('Crear Primera Liga'), findsOneWidget);
      await tester.tap(find.text('Crear Primera Liga'));
      expect(createTapped, isTrue);

      final league = League(
        id: 'LIG-1234',
        name: 'Liga Caribe',
        pin: '4829',
        createdAt: DateTime(2026, 11, 1),
        participants: ['Ana', 'Luis'],
      );

      await tester.pumpWidget(
        wrap(
          LocalLeaguesTab(
            localLeagues: [league],
            activeId: 'LIG-1234',
            onCreateLeague: () {},
            onActivateLeague: (l) => activated = l,
            onDeleteLeague: (l) => deleted = l,
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('local_league_LIG-1234')),
        findsOneWidget,
      );
      expect(find.text('ACTIVA'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.delete_outline));
      expect(deleted?.id, 'LIG-1234');
      expect(activated, isNull);
    });

    testWidgets(
      'ServerLeaguesTab maneja error con Reintentar y filtra por búsqueda',
      (tester) async {
        var refreshed = false;

        await tester.pumpWidget(
          wrap(
            ServerLeaguesTab(
              isLoading: false,
              error: 'No se pudieron cargar las ligas del servidor.',
              serverLeagues: const [],
              searchQuery: '',
              localIds: const {},
              activeId: null,
              onSearchChanged: (_) {},
              onRefresh: () async => refreshed = true,
              onActivateLocal: (_, __) {},
              onJoinServerLeague: (_, __) {},
              onDeleteServerLeague: (_, __) {},
            ),
          ),
        );

        expect(
          find.text('No se pudieron cargar las ligas del servidor.'),
          findsOneWidget,
        );
        await tester.tap(find.text('Reintentar'));
        await tester.pump();
        expect(refreshed, isTrue);

        var latestQuery = '';
        await tester.pumpWidget(
          wrap(
            ServerLeaguesTab(
              isLoading: false,
              error: null,
              serverLeagues: const [
                {
                  'id': 'LIG-1111',
                  'name': 'Copa Norte',
                  'participantsCount': 4,
                },
                {
                  'id': 'LIG-2222',
                  'name': 'Torneo Sur',
                  'participantsCount': 6,
                },
              ],
              searchQuery: 'Norte',
              localIds: const {},
              activeId: null,
              onSearchChanged: (q) => latestQuery = q,
              onRefresh: () async {},
              onActivateLocal: (_, __) {},
              onJoinServerLeague: (_, __) {},
              onDeleteServerLeague: (_, __) {},
            ),
          ),
        );

        expect(
          find.byKey(const ValueKey('server_league_LIG-1111')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('server_league_LIG-2222')),
          findsNothing,
        );

        await tester.enterText(find.byType(TextField), 'Sur');
        expect(latestQuery, 'Sur');
      },
    );
  });

  group('Barrel league_dialogs.dart', () {
    testWidgets('showAddParticipantDialog abre y envía nombre recortado', (
      tester,
    ) async {
      String? addedName;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showAddParticipantDialog(
                    context,
                    onAdd: (name) async => addedName = name,
                  );
                },
                child: const Text('Abrir diálogo'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Abrir diálogo'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo Participante'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Carlos  ');
      await tester.tap(find.text('Agregar'));
      await tester.pumpAndSettle();

      expect(addedName, 'Carlos');
    });
  });
}
