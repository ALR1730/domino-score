import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:domino_score/models/game_state.dart';

/// Clave de prefs usada por [GameState.casual] (debe coincidir con el modelo).
const String _casualKey = 'domino_casual_game_state_v2';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // Caché de SharedPreferences limpia antes de cada test.
    SharedPreferences.setMockInitialValues({});
  });

  group('GameState — marcador y rondas', () {
    test('arranca en cero y sin ganador', () {
      final state = GameState(skipLoadFromPrefs: true);
      expect(state.totalE1, 0);
      expect(state.totalE2, 0);
      expect(state.ganador, 0);
      expect(state.isGameOver, isFalse);
      expect(state.rondas, isEmpty);
    });

    test('acumula puntos por equipo', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.agregarRonda(1, 30);
      state.agregarRonda(2, 20);
      state.agregarRonda(1, 15);

      expect(state.totalE1, 45);
      expect(state.totalE2, 20);
      expect(state.rondasE1Count, 2);
      expect(state.rondasE2Count, 1);
    });

    test('ignora rondas con puntos <= 0', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.agregarRonda(1, 0);
      state.agregarRonda(2, -5);
      expect(state.rondas, isEmpty);
    });

    test('declara ganador al alcanzar la meta', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 50);
      state.agregarRonda(1, 50);
      expect(state.ganador, 1);
      expect(state.isGameOver, isTrue);
      expect(state.ganadorNombre, state.nombreE1);
    });

    test('empate al llegar ambos a la meta lo gana el último en anotar (ganador 1 tiene prioridad)', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 30);
      state.agregarRonda(2, 30);
      state.agregarRonda(1, 30);
      // totalE1 >= meta se evalúa primero
      expect(state.ganador, 1);
    });

    test('editar y eliminar rondas recalcula el marcador', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.agregarRonda(1, 10);
      state.agregarRonda(2, 20);

      state.editarRonda(0, 40);
      expect(state.totalE1, 40);

      state.eliminarRonda(1);
      expect(state.totalE2, 0);
      expect(state.rondas.length, 1);
    });

    test('editarRonda y eliminarRonda toleran índices fuera de rango', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.agregarRonda(1, 10);
      state.editarRonda(5, 99);
      state.eliminarRonda(5);
      expect(state.totalE1, 10);
      expect(state.rondas.length, 1);
    });

    test('reiniciarPartida limpia las rondas', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.agregarRonda(1, 10);
      state.reiniciarPartida();
      expect(state.rondas, isEmpty);
      expect(state.totalE1, 0);
      expect(state.isGameOver, isFalse);
    });
  });

  group('GameState — transición de fin de partida', () {
    test('consumeJustFinished se dispara una sola vez al terminar', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 30);
      expect(state.consumeJustFinished(), isFalse);

      state.agregarRonda(1, 30);
      expect(state.consumeJustFinished(), isTrue);
      expect(state.consumeJustFinished(), isFalse, reason: 'no debe repetirse');
    });

    test('no se dispara si el estado nunca llega a terminar', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 30);
      state.agregarRonda(1, 10);
      expect(state.consumeJustFinished(), isFalse);
    });

    test('eliminar la ronda decisiva vuelve a permitir el registro', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 30);
      state.agregarRonda(1, 30);
      expect(state.consumeJustFinished(), isTrue);

      state.eliminarRonda(0);
      expect(state.isGameOver, isFalse);
      expect(state.consumeJustFinished(), isFalse);

      state.agregarRonda(2, 30);
      expect(state.consumeJustFinished(), isTrue);
    });

    test('reiniciarPartida resetea la transición', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 30);
      state.agregarRonda(1, 30);
      state.consumeJustFinished();

      state.reiniciarPartida();
      expect(state.consumeJustFinished(), isFalse);

      state.agregarRonda(1, 30);
      expect(state.consumeJustFinished(), isTrue);
    });

    test('bajar la meta hasta el marcador actual no re-dispara un fin ya consumido', () {
      final state = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 200);
      state.agregarRonda(1, 50);
      expect(state.consumeJustFinished(), isFalse);

      state.setMetaPuntos(50);
      expect(state.consumeJustFinished(), isTrue);
      expect(state.consumeJustFinished(), isFalse);
    });
  });

  group('GameState — persistencia', () {
    test('guardar y recargar conserva rondas, meta y nombres', () async {
      final first = GameState(skipLoadFromPrefs: true, initialMetaPuntos: 150);
      first.setNombreE1('Ana');
      first.setNombreE2('Beto');
      first.agregarRonda(1, 25);
      first.agregarRonda(2, 10);
      // _saveToPrefs es asíncrono: ceder el turno para que complete.
      await Future<void>.delayed(Duration.zero);

      final reloaded = GameState();
      // La carga desde prefs es asíncrona.
      await Future<void>.delayed(Duration.zero);

      expect(reloaded.isLoaded, isTrue);
      expect(reloaded.metaPuntos, 150);
      expect(reloaded.nombreE1, 'Ana');
      expect(reloaded.nombreE2, 'Beto');
      expect(reloaded.rondas.length, 2);
      expect(reloaded.totalE1, 25);
      expect(reloaded.totalE2, 10);
    });

    test('una partida restaurada ya terminada NO se marca como recién terminada', () async {
      SharedPreferences.setMockInitialValues({
        _casualKey: '{"metaPuntos":30,"nombreE1":"Ana","nombreE2":"Beto",'
            '"rondas":[{"equipo":1,"puntos":30}]}',
      });

      final state = GameState();
      await Future<void>.delayed(Duration.zero);

      expect(state.isGameOver, isTrue);
      expect(state.consumeJustFinished(), isFalse,
          reason: 'la línea base se fija al cargar: no re-registrar partidas antiguas');
    });

    test('nombre vacío no sobrescribe el valor actual', () {
      final state = GameState(skipLoadFromPrefs: true);
      state.setNombreE1('   ');
      expect(state.nombreE1, isNotEmpty);
    });
  });
}
