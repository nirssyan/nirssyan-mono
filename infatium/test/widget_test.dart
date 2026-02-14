// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:makefeed/app.dart';

void main() {
  testWidgets('Shows splash with infatium title', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(testMode: true));
    // Дать время анимации напечатать весь текст и сплэшу отображаться минимум 800 мс
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('infatium'), findsOneWidget);
  });
}
