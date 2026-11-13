import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rezervisime_mobile/services/api_client.dart';

void main() {
  test('401 from the active session signals expiry', () async {
    final api =
        ApiClient(client: MockClient((_) async => http.Response('', 401)));
    var expired = 0;
    api.setToken('current');
    api.onSessionExpired = () => expired++;

    await expectLater(api.get('/profile'), throwsA(isA<ApiException>()));
    expect(expired, 1);
  });

  test('401 from an earlier session leaves the current session active',
      () async {
    final response = Completer<http.Response>();
    final api = ApiClient(client: MockClient((_) => response.future));
    var expired = 0;
    api.setToken('old');
    api.onSessionExpired = () => expired++;
    final request = api.get('/profile');
    api.setToken('new');
    response.complete(http.Response('', 401));

    await expectLater(request, throwsA(isA<ApiException>()));
    expect(expired, 0);
    expect(api.token, 'new');
  });
}
