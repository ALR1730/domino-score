import 'package:flutter_test/flutter_test.dart';
import 'package:domino_score/main.dart';

void main() {
  testWidgets('Dominó Score smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DominoApp());
    await tester.pumpAndSettle();

    expect(find.text('Dominó Score'), findsOneWidget);
    expect(find.text('Historial de Rondas'), findsNothing); // It's uppercase
    expect(find.text('HISTORIAL DE RONDAS'), findsOneWidget);
  });
}
