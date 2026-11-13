import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rezervisime_mobile/screens/auth/password_reset_screen.dart';

void main() {
  testWidgets('Reset lozinke provjerava e-mail prije slanja', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PasswordResetScreen()));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.text('Unesite ispravnu e-mail adresu.'), findsOneWidget);
  });
}
