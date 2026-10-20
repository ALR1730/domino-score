import 'package:flutter_test/flutter_test.dart';

import 'package:domino_score/models/leaderboard_entry.dart';

void main() {
  group('NameParser.extractMembers', () {
    test('separa con los separadores habituales', () {
      expect(NameParser.extractMembers('Juan y Pedro'), ['Juan', 'Pedro']);
      expect(NameParser.extractMembers('Ana & Luis'), ['Ana', 'Luis']);
      expect(NameParser.extractMembers('Carlos / Marcos'), ['Carlos', 'Marcos']);
      expect(NameParser.extractMembers('Maria, Pedro'), ['Maria', 'Pedro']);
      expect(NameParser.extractMembers('Ana e Ines'), ['Ana', 'Ines']);
      expect(NameParser.extractMembers('Ana and Luis'), ['Ana', 'Luis']);
    });

    test('normaliza mayúsculas/minúsculas y espacios', () {
      expect(NameParser.extractMembers('  jUAN   y   pEDRO '), ['Juan', 'Pedro']);
    });

    test('devuelve el nombre completo si no hay separador', () {
      expect(NameParser.extractMembers('Juan Perez'), ['Juan Perez']);
    });

    test('lista vacía para texto vacío', () {
      expect(NameParser.extractMembers('   '), isEmpty);
      expect(NameParser.extractMembers(''), isEmpty);
    });
  });

  group('NameParser.removeDiacritics', () {
    test('quita tildes y la eñe', () {
      expect(NameParser.removeDiacritics('Efraín'), 'Efrain');
      expect(NameParser.removeDiacritics('MUÑOZ'), 'MUNOZ');
      expect(NameParser.removeDiacritics('José Ángel'), 'Jose Angel');
    });

    test('deja el texto sin diacríticos intacto', () {
      expect(NameParser.removeDiacritics('juan_pedro'), 'juan_pedro');
    });
  });

  group('NameParser.generateTeamKey', () {
    test('es independiente del orden y de los diacríticos', () {
      final a = NameParser.generateTeamKey(['Carlos', 'Juan']);
      final b = NameParser.generateTeamKey(['Juan', 'Carlos']);
      expect(a, 'carlos_juan');
      expect(a, b);
      expect(
        NameParser.generateTeamKey(['Efraín', 'Ana']),
        NameParser.generateTeamKey(['Ana', 'Efrain']),
      );
    });

    test('vacía si no hay miembros', () {
      expect(NameParser.generateTeamKey([]), '');
    });
  });

  group('NameParser.formatTeamDisplayName', () {
    test('un miembro: tal cual', () {
      expect(NameParser.formatTeamDisplayName(['Ana']), 'Ana');
    });

    test('dos miembros: unidos con &', () {
      expect(NameParser.formatTeamDisplayName(['Ana', 'Luis']), 'Ana & Luis');
    });

    test('tres o más: separados por comas', () {
      expect(
        NameParser.formatTeamDisplayName(['Ana', 'Luis', 'Pedro']),
        'Ana, Luis, Pedro',
      );
    });

    test('sin miembros: "Equipo"', () {
      expect(NameParser.formatTeamDisplayName([]), 'Equipo');
    });
  });
}
