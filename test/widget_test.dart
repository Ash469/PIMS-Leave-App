import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pims_app/main.dart';
import 'package:pims_app/screens/role_selection_screen.dart';

void main() {
  testWidgets('App should start with role selection screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the role selection screen is shown
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Warden'), findsOneWidget);
  });

  testWidgets('Role selection buttons should be present', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that all three role buttons are present
    expect(find.widgetWithText(ElevatedButton, 'Student'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Parent'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Warden'), findsOneWidget);
  });
}

