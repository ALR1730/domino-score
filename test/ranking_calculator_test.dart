import 'package:domino_score/models/leaderboard_entry.dart';
import 'package:domino_score/models/league.dart';
import 'package:domino_score/services/ranking_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

LeagueMatch _match({
  required String id,
  required DateTime date,
  String t1 = 'Ana',
  String t2 = 'Luis',
  List<String>? m1,
  List<String>? m2,
  int s1 = 100,
  int s2 = 50,
  int winner = 1,
}) {
  final members1 = m1 ?? NameParser.extractMembers(t1);
  final members2 = m2 ?? NameParser.extractMembers(t2);
  return LeagueMatch(
    id: id,
    date: date,
    team1DisplayName: t1,
    team2DisplayName: t2,
    team1Members: members1,
    team2Members: members2,
    score1: s1,
    score2: s2,
    winnerTeam: winner,
  );
}

void main() {
  group('RankingCalculator.sortTeams', () {
    test('ordena por victorias, luego winRate, luego puntos', () {
      final a = TeamStats(key: 'a', displayName: 'A', members: ['A'])
        ..wins = 2
        ..matchesPlayed = 4
        ..totalPoints = 300;
      final b = TeamStats(key: 'b', displayName: 'B', members: ['B'])
        ..wins = 2
        ..matchesPlayed = 4
        ..totalPoints = 500; // mismo wins y rate, más puntos
      final c = TeamStats(key: 'c', displayName: 'C', members: ['C'])
        ..wins = 2
        ..matchesPlayed = 2; // más winRate
      final d = TeamStats(key: 'd', displayName: 'D', members: ['D'])
        ..wins = 1
        ..matchesPlayed = 1;

      final ranked = RankingCalculator.sortTeams([d, b, a, c]);
      expect(ranked.map((t) => t.key).toList(), ['c', 'b', 'a', 'd']);
    });
  });

  group('RankingCalculator.sortPlayers', () {
    test('ordena por victorias y luego winRate', () {
      final a = PlayerStats(key: 'a', name: 'A')
        ..wins = 1
        ..matchesPlayed = 3; // rate 0.33
      final b = PlayerStats(key: 'b', name: 'B')
        ..wins = 1
        ..matchesPlayed = 1; // rate 1.0
      final c = PlayerStats(key: 'c', name: 'C')
        ..wins = 3
        ..matchesPlayed = 4;

      final ranked = RankingCalculator.sortPlayers([a, b, c]);
      expect(ranked.map((p) => p.key).toList(), ['c', 'b', 'a']);
    });
  });

  group('RankingCalculator.aggregateTeamsInto', () {
    test('acumula partidas ganadas, jugadas y puntos', () {
      final agg = <String, TeamStats>{};
      RankingCalculator.aggregateTeamsInto(agg, [
        _match(id: '1', date: DateTime(2026, 1, 1), winner: 1),
        _match(id: '2', date: DateTime(2026, 1, 2), winner: 2),
      ]);

      final ana = agg['ana']!;
      expect(ana.matchesPlayed, 2);
      expect(ana.wins, 1);
      expect(ana.totalPoints, 200);

      final luis = agg['luis']!;
      expect(luis.matchesPlayed, 2);
      expect(luis.wins, 1);
      expect(luis.totalPoints, 100);
    });

    test('suma sobre estadísticas ya presentes en el mapa destino', () {
      final agg = <String, TeamStats>{
        'ana': TeamStats(key: 'ana', displayName: 'Ana', members: ['Ana'])
          ..wins = 5
          ..matchesPlayed = 5
          ..totalPoints = 500,
      };

      RankingCalculator.aggregateTeamsInto(agg, [
        _match(id: '1', date: DateTime(2026, 1, 1), winner: 1),
      ]);

      expect(agg['ana']!.wins, 6);
      expect(agg['ana']!.matchesPlayed, 6);
      expect(agg['ana']!.totalPoints, 600);
    });

    test('normaliza equipos escritos en distinto orden', () {
      final agg = <String, TeamStats>{};
      RankingCalculator.aggregateTeamsInto(agg, [
        _match(
            id: '1',
            date: DateTime(2026, 1, 1),
            m1: ['Ana', 'Luis'],
            m2: ['X', 'Y']),
        _match(
            id: '2',
            date: DateTime(2026, 1, 2),
            m1: ['Luis', 'Ana'],
            m2: ['X', 'Y'],
            winner: 1),
      ]);
      expect(agg.length, 2, reason: 'ana_luis (con orden distinto) + x_y');
      expect(agg['ana_luis']!.matchesPlayed, 2);
    });
  });

  group('RankingCalculator.aggregatePlayersInto', () {
    test('acumula por jugador normalizado', () {
      final agg = <String, PlayerStats>{};
      RankingCalculator.aggregatePlayersInto(agg, [
        _match(
            id: '1',
            date: DateTime(2026, 1, 1),
            m1: ['Efraín', 'Ana'],
            m2: ['Luis', 'Pedro'],
            winner: 2),
        _match(
            id: '2',
            date: DateTime(2026, 1, 2),
            m1: ['Efrain', 'Ana'],
            m2: ['Luis', 'Pedro'],
            winner: 1),
      ]);

      expect(agg['efrain']!.matchesPlayed, 2);
      expect(agg['efrain']!.wins, 1);
      expect(agg['luis']!.wins, 1);
      expect(agg['pedro']!.wins, 1);
    });

    test('ignora nombres vacíos', () {
      final agg = <String, PlayerStats>{};
      RankingCalculator.aggregatePlayersInto(agg, [
        _match(id: '1', date: DateTime(2026, 1, 1), m1: ['  '], m2: ['Luis']),
      ]);
      expect(agg.containsKey(''), isFalse);
      expect(agg.length, 1);
    });
  });

  group('RankingCalculator — fusión y atajos', () {
    test('mergeTeamsInto copia la primera vez y suma después', () {
      final target = <String, TeamStats>{};
      final source = <String, TeamStats>{
        'ana': TeamStats(key: 'ana', displayName: 'Ana', members: ['Ana'])
          ..wins = 2
          ..matchesPlayed = 3
          ..totalPoints = 300,
      };

      RankingCalculator.mergeTeamsInto(target, source);
      expect(target['ana']!.wins, 2);
      expect(identical(target['ana'], source['ana']), isFalse,
          reason: 'debe copiar, no aliasar');

      RankingCalculator.mergeTeamsInto(target, source);
      expect(target['ana']!.wins, 4);
      expect(target['ana']!.matchesPlayed, 6);
      expect(target['ana']!.totalPoints, 600);
    });

    test('mergePlayersInto suma victorias y partidas', () {
      final target = <String, PlayerStats>{};
      final source = <String, PlayerStats>{
        'ana': PlayerStats(key: 'ana', name: 'Ana')
          ..wins = 1
          ..matchesPlayed = 2,
      };
      RankingCalculator.mergePlayersInto(target, source);
      RankingCalculator.mergePlayersInto(target, source);
      expect(target['ana']!.wins, 2);
      expect(target['ana']!.matchesPlayed, 4);
    });

    test('rankTeamsFromMatches y rankPlayersFromMatches agregan y ordenan', () {
      final teams = RankingCalculator.rankTeamsFromMatches([
        _match(id: '1', date: DateTime(2026, 1, 1), winner: 2),
      ]);
      expect(teams.first.key, 'luis');
      expect(teams.first.wins, 1);

      final players = RankingCalculator.rankPlayersFromMatches([
        _match(id: '1', date: DateTime(2026, 1, 1), winner: 2),
      ]);
      expect(players.first.key, 'luis');
    });
  });
}
