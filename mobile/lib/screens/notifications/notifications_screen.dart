import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/reservation.dart";
import "../../providers/notifications_provider.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  String _dayGroup(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return "Danas";
    if (diff == 1) return "Juce";
    if (diff < 7) return "Ova sedmica";
    return "Ranije";
  }

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<NotificationsProvider>();
    final items = prov.items;

    // Grupisanje po danu.
    final groups = <String, List<NotificationDto>>{};
    for (final n in items) {
      groups.putIfAbsent(_dayGroup(n.createdAt), () => []).add(n);
    }
    const order = ["Danas", "Juce", "Ova sedmica", "Ranije"];
    final sortedKeys = order.where((k) => groups.containsKey(k)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Obavijesti"),
        actions: [
          if (prov.unread > 0)
            TextButton(
              onPressed: prov.loading || prov.marking
                  ? null
                  : () async {
                      try {
                        await prov.markAllRead();
                      } catch (error) {
                        if (context.mounted) showError(context, error);
                      }
                    },
              child: const Text("Označi sve kao pročitano"),
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<NotificationsProvider>().refresh(),
          child: prov.error != null && items.isEmpty
              ? ListView(children: [
                  TextButton(
                      onPressed: prov.refresh,
                      child: const Text(
                          "Učitavanje nije uspjelo. Pokušaj ponovo."))
                ])
              : prov.loading && items.isEmpty
                  ? const LoadingView()
                  : items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 160),
                          EmptyView("Nemas obavijesti.",
                              icon: Icons.notifications_none),
                        ])
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            for (final key in sortedKeys) ...[
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 8),
                                child: Text(key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textSecondary)),
                              ),
                              ...groups[key]!.map((n) => _NotificationTile(n)),
                            ],
                            if (prov.error != null)
                              TextButton(
                                  onPressed: prov.refresh,
                                  child: const Text("Pokušaj ponovo")),
                            if (prov.hasMore)
                              TextButton(
                                onPressed: prov.loading || prov.marking
                                    ? null
                                    : prov.loadMore,
                                child: const Text("Učitaj starije obavijesti"),
                              ),
                          ],
                        ),
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationDto notification;
  const _NotificationTile(this.notification);

  @override
  Widget build(BuildContext context) {
    final tf = DateFormat("HH:mm");
    final unread = !notification.isRead;
    return GestureDetector(
      onTap: unread
          ? () async {
              try {
                await context
                    .read<NotificationsProvider>()
                    .markRead(notification.id);
              } catch (error) {
                if (context.mounted) showError(context, error);
              }
            }
          : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.primary.withValues(alpha: 0.06)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: unread
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.notifications,
                  color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(notification.title,
                            style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.bold
                                    : FontWeight.w500)),
                      ),
                      Text(tf.format(notification.createdAt),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(notification.text,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (unread)
              Container(
                margin: const EdgeInsets.only(left: 8, top: 4),
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: AppColors.primary, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
