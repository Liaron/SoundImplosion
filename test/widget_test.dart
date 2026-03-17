import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:soundimplosion/platform_layout.dart';

void main() {
  testWidgets('PlatformLayout shows mobile body on Flutter test runtime', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PlatformLayout(
          mobileBody: Text('mobile'),
          webBody: Text('web'),
        ),
      ),
    );

    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('web'), findsNothing);
  });
}
