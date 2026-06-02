import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:formula_fix/main.dart';

void main() {
  testWidgets('App smoke test - verifies app can be built', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FormulaFixApp(),
      ),
    );

    expect(find.text('FormulaFix'), findsOneWidget);
  });
}
