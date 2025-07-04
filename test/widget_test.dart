import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pims_app/main.dart';
import 'package:pims_app/screens/role_selection_screen.dart';

@GenerateMocks([SharedPreferences])
void main() {
 

  setUp(() {
   
    SharedPreferences.setMockInitialValues({}); // Reset mock preferences
  });

  testWidgets('App should start with role selection screen', (WidgetTester tester) async {


    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
     await tester.pumpAndSettle(); // Wait for navigation to complete

    // Verify that the role selection screen is shown
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(find.text('Who are you?'), findsOneWidget);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('Parent'), findsOneWidget);
    expect(find.text('Warden'), findsOneWidget);
    expect(find.text('Guard'), findsOneWidget);
  });

  testWidgets('Role selection buttons should be present', (WidgetTester tester) async {
    // Mock shared preferences to simulate no user logged in
   

    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle(); 
    // Verify that all role buttons are present
    expect(find.widgetWithText(ElevatedButton, 'Student'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Parent'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Warden'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Guard'), findsOneWidget);
  });
}

