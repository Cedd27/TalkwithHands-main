// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:guesssme1/main.dart';

void main() {
  testWidgets('Guess Me game builds and displays questions', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const GuessMeApp());

    // Verify that the game screen renders
    expect(find.byType(GuessMeScreen), findsOneWidget);
    
    // Verify hearts are displayed (lives indicator)
    expect(find.byIcon(Icons.favorite), findsWidgets);
    
    // Verify the Score text is displayed
    expect(
      find.byWidgetPredicate(
        (widget) => widget is RichText && widget.text.toPlainText().contains('Score'),
      ),
      findsOneWidget,
    );

    // Verify the round label is displayed
    expect(find.textContaining('Round'), findsOneWidget);
    
    // Verify TIME text is displayed
    expect(find.textContaining('TIME:'), findsOneWidget);
  });
}
