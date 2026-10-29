import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/salon.dart";
import "../../models/reservation.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../booking/booking_screen.dart";

class SalonProfileScreen extends StatefulWidget {
  final int salonId;
  const SalonProfileScreen({super.key, required this.salonId});
  @override
  State<SalonProfileScreen> createState() => _SalonProfileScreenState();
}

class _SalonProfileScreenState extends State<SalonProfileScreen> {
  late Future<_SalonData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SalonData> _load() async {
    final api = context.read<ApiService>();
    final salon = await api.getSalon(widget.salonId);
    final services = await api.getServices(salonId: widget.salonId);
    final reviews = await api.getSalonReviews(widget.salonId);
    return _SalonData(salon, services.items, reviews);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_SalonData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snap.hasError) {
            return Center(child: Text("Greska: ${snap.error}"));
          }
          final d = snap.data!;
          final byCategory = <String, List<ServiceDto>>{};
          for (final s in d.services) {
            byCategory.putIfAbsent(s.serviceCategoryName, () => []).add(s);
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(d.salon.name),
                  background: Container(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    child: const Center(
                        child: Icon(Icons.store,
                            size: 72, color: AppColors.primary)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        StarRating(d.salon.averageRating),
                        const SizedBox(width: 8),
                        Text(
                            d.salon.reviewCount > 0
                                ? "${d.salon.averageRating.toStringAsFixed(1)} · ${d.salon.reviewCount} recenzija"
                                : "Nema recenzija",
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                            child: Text("${d.salon.address}, ${d.salon.cityName}",
                                style: const TextStyle(
                                    color: AppColors.textSecondary))),
                      ]),
                      if (d.salon.description != null) ...[
                        const SizedBox(height: 12),
                        Text(d.salon.description!),
                      ],
                      const SizedBox(height: 24),
                      const Text("Usluge",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      ...byCategory.entries.map((e) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(e.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.primary)),
                              ),
                              ...e.value.map((s) => _ServiceRow(
                                  service: s, salon: d.salon)),
                            ],
                          )),
                      const SizedBox(height: 24),
                      const Text("Recenzije",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      if (d.reviews.isEmpty)
                        const Text("Jos nema recenzija.",
                            style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...d.reviews.map((r) => _ReviewRow(r)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SalonData {
  final SalonDto salon;
  final List<ServiceDto> services;
  final List<ReviewDto> reviews;
  _SalonData(this.salon, this.services, this.reviews);
}

class _ServiceRow extends StatelessWidget {
  final ServiceDto service;
  final SalonDto salon;
  const _ServiceRow({required this.service, required this.salon});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text("${service.durationMinutes} min",
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text("${service.price.toStringAsFixed(2)} KM",
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16)),
            onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        BookingScreen(salon: salon, service: service))),
            child: const Text("Rezervisi"),
          ),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  final ReviewDto review;
  const _ReviewRow(this.review);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: Text(review.clientName,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
            StarRating(review.rating.toDouble(), size: 14),
          ]),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(review.comment!),
          ],
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: review.tags
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize:
                            MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
