import "dart:async";
import "package:flutter/foundation.dart";
import "../models/reservation.dart";
import "../services/api_service.dart";

/// Drzi listu notifikacija i broj nepročitanih.
/// Automatsko osvjezavanje kroz polling (bez rucnog refresh-a) - uputa 6.5.
class NotificationsProvider extends ChangeNotifier {
  final ApiService _api;
  NotificationsProvider(this._api);

  List<NotificationDto> _items = [];
  int _unread = 0;
  Timer? _timer;

  List<NotificationDto> get items => _items;
  int get unread => _unread;

  void startPolling() {
    _timer?.cancel();
    refresh();
    // Polling svakih 15 sekundi.
    _timer = Timer.periodic(const Duration(seconds: 15), (_) => refresh());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    try {
      final res = await _api.getNotifications();
      _items = res.items;
      _unread = await _api.getUnreadCount();
      notifyListeners();
    } catch (_) {
      // Tiho - polling ne smije rusiti UI.
    }
  }

  Future<void> markRead(int id) async {
    await _api.markNotificationRead(id);
    await refresh();
  }

  Future<void> markAllRead() async {
    final unreadItems = _items.where((n) => !n.isRead).toList();
    for (final n in unreadItems) {
      await _api.markNotificationRead(n.id);
    }
    await refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
