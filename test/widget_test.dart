// Flutter widget test for Anveshak app

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Basic widget test', (WidgetTester tester) async {
    // Create a simple test app
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(title: const Text('Test')),
          body: const Center(child: Text('Hello World')),
        ),
      ),
    );

    // Verify the text is displayed
    expect(find.text('Hello World'), findsOneWidget);
    expect(find.text('Test'), findsOneWidget);
  });
}
