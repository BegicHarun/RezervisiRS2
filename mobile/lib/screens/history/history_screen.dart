import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/reservation.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "review_screen.dart";

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<ReservationDto>> _future;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  int _revision = 0;
  List<ReservationDto> _items = [];

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReservationDto>> _load() async {
    final revision = ++_revision;
    final result = await context.read<ApiService>().getMyReservations(page: 1);
    if (mounted && revision == _revision) {
      _page = 1;
      _hasMore = result.page < result.totalPages;
      _items = result.items;
    }
    return result.items;
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    try {
      await _future;
    } catch (_) {
      // The FutureBuilder displays the failure and offers a retry.
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final revision = _revision;
    setState(() => _loadingMore = true);
    try {
      final result =
          await context.read<ApiService>().getMyReservations(page: _page + 1);
      if (!mounted || revision != _revision) return;
      final rows = {
        for (final item in [..._items, ...result.items]) item.id: item
      };
      setState(() {
        _items = rows.values.toList();
        _page = result.page;
        _hasMore = result.page < result.totalPages;
      });
    } catch (error) {
      if (mounted && revision == _revision) showError(context, error);
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historija")),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<ReservationDto>>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snap.hasError) {
                return ListView(children: [
                  const SizedBox(height: 160),
                  TextButton(
                      onPressed: _refresh,
                      child: const Text(
                          "Učitavanje nije uspjelo. Pokušaj ponovo.")),
                ]);
              }
              final all = _items;
              final completed =
                  all.where((r) => r.status == "Completed").toList();
              final totalSpent = completed
                  .where((r) => r.isPaid)
                  .fold<double>(0, (sum, r) => sum + r.price);

              // Grupisanje po mjesecu.
              final byMonth = <String, List<ReservationDto>>{};
              final monthFmt = DateFormat("MMMM yyyy");
              for (final r in completed) {
                final key = monthFmt.format(r.startTime);
                byMonth.putIfAbsent(key, () => []).add(r);
              }

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      _StatCard(
                          label: "Učitane posjete",
                          value: "${completed.length}",
                          icon: Icons.check_circle_outline),
                      const SizedBox(width: 12),
                      _StatCard(
                          label: "Plaćeno za učitane posjete",
                          value: "${totalSpent.toStringAsFixed(2)} USD",
                          icon: Icons.payments_outlined),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (completed.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 80),
                      child: EmptyView(
                          "Nema završenih termina na učitanim stranicama.",
                          icon: Icons.history),
                    )
                  else
                    ...byMonth.entries.expand((e) => [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(e.key,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textSecondary)),
                          ),
                          ...e.value.map((r) => _HistoryRow(
                              reservation: r, onReviewed: _refresh)),
                        ]),
                  if (_hasMore)
                    TextButton(
                      onPressed: _loadingMore ? null : _loadMore,
                      child: Text(_loadingMore
                          ? "Učitavanje…"
                          : "Učitaj starije rezervacije"),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ReservationDto reservation;
  final VoidCallback onReviewed;
  const _HistoryRow({required this.reservation, required this.onReviewed});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("dd.MM.yyyy");
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reservation.serviceName,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                    "${reservation.salonName} Â· ${df.format(reservation.startTime)}",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          if (reservation.canReview)
            TextButton(
              onPressed: () async {
                final done = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ReviewScreen(reservation: reservation)));
                if (done == true) onReviewed();
              },
              child: const Text("Ocijeni"),
            )
          else
            const Icon(Icons.check_circle,
                color: AppColors.completed, size: 20),
        ],
      ),
    );
  }
}
