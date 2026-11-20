import 'package:domino_score/models/game_state.dart';
import 'package:domino_score/screens/domino_game_screen.dart';
import 'package:domino_score/services/leaderboard_service.dart';
import 'package:domino_score/widgets/points_dialog.dart';
import 'package:domino_score/widgets/winner_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LeaderboardService().resetLeaderboard();
  });

  testWidgets(
      'DominoGameScreen registra 2 partidas consecutivas al reiniciar desde WinnerDialog',
      (WidgetTester tester) async {
    final gameState = GameState(
      skipLoadFromPrefs: true,
      initialMetaPuntos: 50,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DominoGameScreen(
          gameState: gameState,
          ownsGameState: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Partida 1
    await tester.tap(find.text('Sumar').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(PointsDialog),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.byType(WinnerDialog), findsOneWidget);
    expect(
      find.text('Guardado en este dispositivo (no afecta ligas)'),
      findsOneWidget,
    );
    expect(LeaderboardService().teams.length, 2);
    expect(
      LeaderboardService()
          .teams
          .firstWhere((t) => t.key == 'nosotros')
          .matchesPlayed,
      1,
    );
    expect(LeaderboardService().teams.first.matchesPlayed, 1);

    // Iniciar Nueva Partida desde WinnerDialog
    await tester.tap(find.text('Iniciar Nueva Partida'));
    await tester.pumpAndSettle();

    // Partida 2
    await tester.tap(find.text('Sumar').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(PointsDialog),
        matching: find.byType(TextField),
      ),
      '50',
    );
    await tester.tap(find.text('Aceptar'));
    await tester.pumpAndSettle();

    expect(find.byType(WinnerDialog), findsOneWidget);
    final nosotros =
        LeaderboardService().teams.firstWhere((t) => t.key == 'nosotros');
    expect(nosotros.matchesPlayed, 2);
    expect(nosotros.wins, 2);
  });
}
