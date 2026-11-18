import 'package:digito/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpCalculator(WidgetTester tester) async {
    // Keep the test viewport close to a typical phone so the portrait layout
    // and the complete keypad are exercised.
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CalculatorApp());
  }

  Future<void> tapKey(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('shows the calculator display and scientific keypad', (
    tester,
  ) async {
    await pumpCalculator(tester);

    expect(find.byType(CalculatorScreen), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);
    expect(find.text('DEG'), findsOneWidget);
    expect(find.text('Sin('), findsOneWidget);
    expect(find.text('='), findsOneWidget);
  });

  testWidgets('evaluates an expression and clears it with AC', (tester) async {
    await pumpCalculator(tester);

    await tapKey(tester, '2');
    await tapKey(tester, '+');
    await tapKey(tester, '3');

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, '2+3');
    // The preview and the keypad both render a 5.
    expect(find.text('5'), findsNWidgets(2));

    await tapKey(tester, '=');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '5',
    );

    await tapKey(tester, 'AC');
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets('records an evaluated expression in history', (tester) async {
    await pumpCalculator(tester);

    await tapKey(tester, '7');
    await tapKey(tester, '×');
    await tapKey(tester, '6');
    await tapKey(tester, '=');
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();

    expect(find.text('History'), findsOneWidget);
    expect(find.text('7×6 ='), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('settings page exposes appearance and calculator options', (
    tester,
  ) async {
    await pumpCalculator(tester);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Digito'), findsAtLeastNWidgets(1));
    expect(find.text('Developer: Chill-Astro Software'), findsOneWidget);
    expect(find.text('Version 1.0.0'), findsOneWidget);
    expect(find.text('Repository'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Angle Unit: Degrees'), findsOneWidget);
    expect(find.text('Decimal Precision'), findsOneWidget);
  });
}
