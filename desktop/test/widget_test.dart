import 'package:flutter_test/flutter_test.dart';
import 'package:rezervisime_desktop/main.dart';
import 'package:rezervisime_desktop/services/api_client.dart';
import 'package:rezervisime_desktop/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Prijava traži korisničko ime i lozinku', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester
        .pumpWidget(RezervisiMeDesktop(apiService: ApiService(ApiClient())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Prijava').last);
    await tester.pumpAndSettle();
    expect(find.text('Unesite korisnicko ime'), findsOneWidget);
    expect(find.text('Unesite lozinku'), findsOneWidget);
  });
}
