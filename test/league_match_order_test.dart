import 'package:domino_score/models/league.dart';
import 'package:flutter_test/flutter_test.dart';

LeagueMatch _match(String id, DateTime date) => LeagueMatch(
      id: id,
      date: date,
      team1DisplayName: 'A & B',
      team2DisplayName: 'C & D',
      team1Members: const ['A', 'B'],
      team2Members: const ['C', 'D'],
      score1: 100,
      score2: 50,
      winnerTeam: 1,
    );

void main() {
  group('League — orden de partidas por fecha', () {
    test('matchesByDateDesc devuelve la más reciente primero', () {
      final league = League(
        id: 'LIG-1',
        name: 'Liga',
        pin: '1234',
        createdAt: DateTime(2026, 1, 1),
        matches: [
          _match('vieja', DateTime(2026, 8, 1, 10, 0)),
          _match('nueva', DateTime(2026, 9, 20, 18, 0)),
          _match('media', DateTime(2026, 8, 15, 12, 0)),
        ],
      );

      final ordered = league.matchesByDateDesc.map((m) => m.id).toList();
      expect(ordered, ['nueva', 'media', 'vieja']);
    });

    test('matchesByDateDesc no muta la lista original', () {
      final league = League(
        id: 'LIG-1',
        name: 'Liga',
        pin: '1234',
        createdAt: DateTime(2026, 1, 1),
        matches: [
          _match('vieja', DateTime(2026, 8, 1)),
          _match('nueva', DateTime(2026, 9, 20)),
        ],
      );

      league.matchesByDateDesc;
      expect(league.matches.first.id, 'vieja',
          reason: 'el getter no debe reordenar la lista subyacente');
    });

    test('sortMatchesByDate ordena in-place de forma descendente', () {
      final league = League(
        id: 'LIG-1',
        name: 'Liga',
        pin: '1234',
        createdAt: DateTime(2026, 1, 1),
        matches: [
          _match('a', DateTime(2026, 8, 1)),
          _match('c', DateTime(2026, 9, 20)),
          _match('b', DateTime(2026, 8, 15)),
        ],
      );

      league.sortMatchesByDate();
      expect(league.matches.map((m) => m.id).toList(), ['c', 'b', 'a']);
    });

    test('misma fecha: no lanza y conserva todas las partidas', () {
      final d = DateTime(2026, 8, 1, 10, 0);
      final league = League(
        id: 'LIG-1',
        name: 'Liga',
        pin: '1234',
        createdAt: DateTime(2026, 1, 1),
        matches: [_match('m1', d), _match('m2', d)],
      );

      final ordered = league.matchesByDateDesc;
      expect(ordered.length, 2);
      expect(ordered.map((m) => m.id).toSet(), {'m1', 'm2'});
    });
  });
}
