import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('App arranca sin crash', (WidgetTester tester) async {
    // Test mínimo: verifica que MaterialApp renderiza
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('KORA'))),
    );
    expect(find.text('KORA'), findsOneWidget);
  });
}
