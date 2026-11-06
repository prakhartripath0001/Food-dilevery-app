// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:client_app/widgets/location_header.dart';

void main() {
  testWidgets('Location header opens address selection', (
    WidgetTester tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LocationHeader(
            addressLabel: 'Home',
            addressDetails: 'Marathahalli, Bengaluru',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Marathahalli, Bengaluru'), findsOneWidget);
    await tester.tap(find.text('Home'));
    expect(tapped, isTrue);
  });
}
