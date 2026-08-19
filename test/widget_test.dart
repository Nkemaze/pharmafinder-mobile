import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_mobile_app/theme/app_theme.dart';

void main() {
  testWidgets('AppTheme builds a light Material 3 theme', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: Text('PharmaFinder')),
      ),
    );
    expect(find.text('PharmaFinder'), findsOneWidget);
  });
}
