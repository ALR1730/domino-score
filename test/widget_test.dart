import 'package:flutter_test/flutter_test.dart';
import 'package:domino_score/main.dart';

void main() {
  testWidgets('Dominó Score ModeSelection smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DominoApp());
    await tester.pumpAndSettle();

    expect(find.text('Dominó Score'), findsOneWidget);
    expect(find.text('Modo Casual'), findsOneWidget);
    expect(find.text('Modo Liga'), findsOneWidget);
    expect(find.text('Ver Ranking General del Servidor'), findsOneWidget);
  });
}
