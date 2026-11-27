import 'dart:io';

import 'package:domino_score/domain/repositories/leaderboard_repository.dart';
import 'package:domino_score/domain/repositories/league_repository.dart';
import 'package:domino_score/models/leaderboard_entry.dart';
import 'package:domino_score/models/league.dart';
import 'package:domino_score/screens/leaderboard_screen.dart';
import 'package:domino_score/services/leaderboard_service.dart';
import 'package:domino_score/services/league_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryLeagueRepository implements ILeagueRepository {
  List<League> localLeagues = const [];
  String? activeId;
  RankingSnapshot? globalSnapshot;

  _InMemoryLeagueRepository({this.globalSnapshot});

  @override
  Future<LocalLeaguesState> loadLocalState() async => LocalLeaguesState(
        leagues: localLeagues.map((l) => League.fromMap(l.toMap())).toList(),
        activeLeagueId: activeId,
      );

  @override
  Future<void> saveLocalState({
    required Iterable<League> leagues,
    required String? activeLeagueId,
  }) async {
    localLeagues = leagues.toList();
    activeId = activeLeagueId;
  }

  @override
  Future<bool> isServerAvailable() async => globalSnapshot != null;

  @override
  Future<List<Map<String, dynamic>>?> fetchServerLeagues() async => const [];

  @override
  Future<League?> createRemoteLeague({
    String? id,
    required String name,
    required String pin,
    required List<String> initialParticipants,
  }) async =>
      null;

  @override
  Future<League?> syncRemoteLeague(League league) async => league;

  @override
  Future<League?> fetchRemoteLeague(String id) async => null;

  @override
  Future<JoinRemoteResult> joinRemoteLeague({
    required String nameOrId,
    required String pin,
  }) async =>
      const JoinRemoteResult(error: 'No encontrada');

  @override
  Future<DeleteRemoteResult> deleteRemoteLeague(
    String id, {
    required String pin,
  }) async =>
      const DeleteRemoteResult(success: true, error: null);

  @override
  Future<List<String>?> addRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) async =>
      null;

  @override
  Future<List<String>?> removeRemoteParticipant({
    required String leagueId,
    required String name,
    required String pin,
  }) async =>
      null;

  @override
  Future<bool> recordRemoteMatch({
    required String leagueId,
    required LeagueMatch match,
    String? leagueName,
    String? pin,
  }) async =>
      true;

  @override
  Future<RankingSnapshot?> fetchGlobalRankings({
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async =>
      globalSnapshot;

  @override
  Future<RankingSnapshot?> fetchLeagueRankings(
    String leagueId, {
    int? year,
    int? month,
    int? tzOffsetMinutes,
  }) async =>
      globalSnapshot;
}

class _InMemoryLeaderboardRepository implements ILeaderboardRepository {
  List<TeamStats> teams;
  List<PlayerStats> players;

  _InMemoryLeaderboardRepository({
    this.teams = const [],
    this.players = const [],
  });

  @override
  Future<LocalLeaderboardState> loadLeaderboard() async =>
      LocalLeaderboardState(teams: teams, players: players);

  @override
  Future<void> saveLeaderboard({
    required Iterable<TeamStats> teams,
    required Iterable<PlayerStats> players,
  }) async {
    this.teams = teams.toList();
    this.players = players.toList();
  }
}

void main() {
  group('Inversión de dependencias (Regla BETA) con repositorios en memoria',
      () {
    test(
        'LeagueService y LeaderboardService operan sin SharedPreferences ni HTTP',
        () async {
      final leagueRepo = _InMemoryLeagueRepository();
      final leaderboardRepo = _InMemoryLeaderboardRepository();

      final leagueService = LeagueService.withRepository(leagueRepo);
      final leaderboardService =
          LeaderboardService.withRepository(leaderboardRepo);
      await Future.wait([
        leagueService.ensureLoaded(),
        leaderboardService.ensureLoaded(),
      ]);

      final created = await leagueService.createLeague(
        name: 'Liga Memoria',
        pin: '4821',
        initialParticipants: ['Ana', 'Luis'],
      );
      expect(leagueRepo.activeId, created.id);
      expect(leagueRepo.localLeagues.length, 1);

      final recorded = await leaderboardService.recordMatch(
        LeagueMatch(
          id: 'mem-m1',
          date: DateTime(2026, 11, 20),
          team1DisplayName: 'Ana & Luis',
          team2DisplayName: 'Pedro & Sofia',
          team1Members: const ['Ana', 'Luis'],
          team2Members: const ['Pedro', 'Sofia'],
          score1: 200,
          score2: 120,
          winnerTeam: 1,
        ),
      );

      expect(recorded, isTrue);
      expect(leaderboardRepo.teams.length, 2);
      expect(leaderboardService.teamsRanked.first.wins, 1);
    });

    test('guardarraíles estáticos BETA: dominio puro y pantallas desacopladas',
        () {
      final domainFiles = Directory('lib/domain')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      expect(domainFiles, isNotEmpty);

      for (final file in domainFiles) {
        final content = file.readAsStringSync();
        expect(content, isNot(contains('package:flutter')));
        expect(content, isNot(contains('package:http')));
        expect(content, isNot(contains('shared_preferences')));
        expect(content, isNot(contains('api_client')));
      }

      for (final dirPath in ['lib/screens', 'lib/widgets']) {
        final uiFiles = Directory(dirPath)
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'));
        for (final file in uiFiles) {
          final content = file.readAsStringSync();
          expect(
            content,
            isNot(contains('api_client.dart')),
            reason: '${file.path} no debe importar ApiClient',
          );
          expect(
            content,
            isNot(contains('shared_preferences')),
            reason: '${file.path} no debe importar SharedPreferences',
          );
        }
      }

      final libFiles = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));
      for (final file in libFiles) {
        expect(
          file.readAsStringSync(),
          isNot(contains('resetForTesting')),
          reason: '${file.path} no debe mantener resetForTesting',
        );
      }
    });
  });

  group('Pantalla consolidada de Clasificaciones', () {
    testWidgets(
        'LeaderboardScreen abre en Dispositivo, filtra, reinicia y cambia a Servidor',
        (tester) async {
      final leagueRepo = _InMemoryLeagueRepository(
        globalSnapshot: RankingSnapshot(
          teams: [
            TeamStats(
              key: 'server_duo',
              displayName: 'Dúo Nube',
              members: const ['Nube 1', 'Nube 2'],
              wins: 9,
              matchesPlayed: 10,
              totalPoints: 1800,
            ),
          ],
          players: [
            PlayerStats(
              key: 'nube_1',
              name: 'Nube 1',
              wins: 9,
              matchesPlayed: 10,
            ),
          ],
          availableMonths: [DateTime(2026, 11)],
        ),
      );
      final leaderboardRepo = _InMemoryLeaderboardRepository(
        teams: [
          TeamStats(
            key: 'ana_luis',
            displayName: 'Ana & Luis',
            members: const ['Ana', 'Luis'],
            wins: 4,
            matchesPlayed: 5,
            totalPoints: 820,
          ),
          TeamStats(
            key: 'carlos_mario',
            displayName: 'Carlos & Mario',
            members: const ['Carlos', 'Mario'],
            wins: 2,
            matchesPlayed: 5,
            totalPoints: 510,
          ),
        ],
        players: [
          PlayerStats(key: 'ana', name: 'Ana', wins: 4, matchesPlayed: 5),
        ],
      );

      final leagueService = LeagueService.withRepository(leagueRepo);
      final leaderboardService =
          LeaderboardService.withRepository(leaderboardRepo);
      await Future.wait([
        leagueService.ensureLoaded(),
        leaderboardService.ensureLoaded(),
      ]);

      await tester.pumpWidget(
        MaterialApp(
          home: LeaderboardScreen(
            leagueService: leagueService,
            leaderboardService: leaderboardService,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Modo Dispositivo inicial (con 2 entradas aparecen en el podio y en la lista)
      expect(find.text('Tabla de Clasificación'), findsOneWidget);
      expect(find.byKey(const ValueKey('rank_team_ana_luis')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('rank_team_carlos_mario')),
        findsOneWidget,
      );

      // Búsqueda local
      await tester.enterText(find.byType(TextField), 'Carlos');
      await tester.pump();
      expect(
        find.byKey(const ValueKey('rank_team_carlos_mario')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('rank_team_ana_luis')), findsNothing);

      // Limpiar búsqueda y probar cambio a Servidor
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();
      await tester.tap(find.text('En el Servidor'));
      await tester.pumpAndSettle();

      expect(find.text('Ranking General'), findsOneWidget);
      expect(find.text('Dúo Nube'), findsOneWidget);
      expect(find.byTooltip('Mes anterior'), findsOneWidget);

      // Volver a Dispositivo y probar reinicio local
      await tester.tap(find.text('En este Dispositivo'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reiniciar clasificación local'));
      await tester.pumpAndSettle();
      expect(find.text('¿Borrar Clasificación?'), findsOneWidget);

      await tester.tap(find.text('Borrar Todo'));
      await tester.pumpAndSettle();

      expect(leaderboardRepo.teams, isEmpty);
      expect(find.text('Ana & Luis'), findsNothing);
    });
  });
}
