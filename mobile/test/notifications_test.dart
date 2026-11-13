import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rezervisime_mobile/providers/notifications_provider.dart';
import 'package:rezervisime_mobile/services/api_client.dart';
import 'package:rezervisime_mobile/services/api_service.dart';

void main() {
  test('Notification refresh preserves loaded pages and marks older items',
      () async {
    final read = <int>{};
    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/unread-count')) {
        return http.Response(jsonEncode(30 - read.length), 200);
      }
      if (path.endsWith('/read')) {
        read.add(int.parse(request.url.pathSegments.reversed.elementAt(1)));
        return http.Response('', 204);
      }
      final page = int.parse(request.url.queryParameters['page']!);
      final size = int.parse(request.url.queryParameters['pageSize']!);
      final ids =
          List.generate(30, (i) => 30 - i).skip((page - 1) * size).take(size);
      return http.Response(
          jsonEncode({
            'page': page,
            'pageSize': size,
            'totalCount': 30,
            'items': [
              for (final id in ids)
                {
                  'id': id,
                  'title': 'Obavijest',
                  'text': 'Tekst',
                  'createdAt': '2026-11-13T12:00:00Z',
                  'isRead': read.contains(id)
                },
            ],
          }),
          200);
    });
    final provider =
        NotificationsProvider(ApiService(ApiClient(client: client)));
    addTearDown(provider.dispose);
    await provider.refresh();
    expect(provider.items.length, 25);
    expect(provider.hasMore, isTrue);
    await provider.loadMore();
    await provider.refresh();
    expect(provider.items.length, 30);
    expect(provider.hasMore, isFalse);
    await provider.markAllRead();
    expect(read.length, 30);
    expect(provider.items.every((item) => item.isRead), isTrue);
  });
}
