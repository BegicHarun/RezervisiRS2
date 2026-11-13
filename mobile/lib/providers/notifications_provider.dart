import "dart:async";
import "package:flutter/foundation.dart";
import "../models/reservation.dart";
import "../services/api_service.dart";

class NotificationsProvider extends ChangeNotifier {
  NotificationsProvider(this._api);

  final ApiService _api;
  static const _pageSize = 25;
  List<NotificationDto> items = [];
  int unread = 0;
  int _limit = _pageSize;
  int _total = 0;
  Timer? _timer;
  bool _disposed = false;
  bool loading = false;
  bool marking = false;
  Object? error;

  bool get hasMore => items.length < _total;

  void startPolling() {
    _timer?.cancel();
    unawaited(refresh());
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> loadMore() => _load(_limit + _pageSize);
  Future<void> refresh() => _load(_limit);

  Future<void> _load(int limit) async {
    if (_disposed || loading || marking) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final rows = <int, NotificationDto>{};
      var page = 1;
      var pages = 1;
      var total = 0;
      do {
        final result =
            await _api.getNotifications(page: page, pageSize: _pageSize);
        if (_disposed) return;
        for (final row in result.items) {
          rows[row.id] = row;
        }
        pages = result.totalPages;
        total = result.totalCount;
        page++;
      } while (page <= pages && rows.length < limit);
      final count = await _api.getUnreadCount();
      if (_disposed) return;
      _limit = limit;
      _total = total;
      items = rows.values.toList();
      unread = count;
    } catch (failure) {
      if (!_disposed) error = failure;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> markRead(int id) => _mark(() => _api.markNotificationRead(id));

  Future<void> markAllRead() => _mark(() async {
        var page = 1;
        while (!_disposed) {
          final result = await _api.getNotifications(page: page, pageSize: 100);
          for (final item in result.items) {
            if (_disposed) return;
            if (!item.isRead) await _api.markNotificationRead(item.id);
          }
          if (page >= result.totalPages) return;
          page++;
        }
      });

  Future<void> _mark(Future<void> Function() action) async {
    if (_disposed || loading || marking) return;
    marking = true;
    notifyListeners();
    try {
      await action();
    } finally {
      marking = false;
      if (!_disposed) await refresh();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopPolling();
    super.dispose();
  }
}
