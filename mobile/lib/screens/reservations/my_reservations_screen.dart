import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/reservation.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "reservation_detail_screen.dart";

class MyReservationsScreen extends StatefulWidget {
  const MyReservationsScreen({super.key});
  @override
  State<MyReservationsScreen> createState() => _MyReservationsScreenState();
}

class _MyReservationsScreenState extends State<MyReservationsScreen> {
  late Future<List<ReservationDto>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ReservationDto>> _load() async {
    final res = await context.read<ApiService>().getMyReservations();
    return res.items;
  }

  Future<void> _refresh() async {
    setState(() { _future = _load(); });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Moje rezervacije")),
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
                  Center(child: Text("Greska: ${snap.error}")),
                ]);
              }
              final items = snap.data!;
              if (items.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 160),
                  EmptyView("Nemas rezervacija.",
                      icon: Icons.event_available),
                ]);
              }
              // Aktivne prvo, pa historija.
              final active = items
                  .where((r) =>
                      r.status == "Pending" || r.status == "Confirmed")
                  .toList();
              final past = items
                  .where((r) =>
                      r.status == "Completed" || r.status == "Cancelled")
                  .toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (active.isNotEmpty) ...[
                    const _GroupLabel("Aktivne"),
                    ...active.map((r) => _ReservationCard(
                        reservation: r, onChanged: _refresh)),
                  ],
                  if (past.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const _GroupLabel("Historija"),
                    ...past.map((r) => _ReservationCard(
                        reservation: r, onChanged: _refresh)),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  final String text;
  const _GroupLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
      );
}

class _ReservationCard extends StatelessWidget {
  final ReservationDto reservation;
  final VoidCallback onChanged;
  const _ReservationCard(
      {required this.reservation, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat("dd.MM.yyyy · HH:mm");
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: () async {
          await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      ReservationDetailScreen(reservation: reservation)));
          onChanged();
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(reservation.serviceName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                StatusBadge(reservation.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(reservation.salonName,
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.schedule,
                  size: 16, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(df.format(reservation.startTime),
                  style: const TextStyle(fontSize: 13)),
              const Spacer(),
              Text("${reservation.price.toStringAsFixed(2)} KM",
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ]),
          ],
        ),
      ),
    );
  }
}
