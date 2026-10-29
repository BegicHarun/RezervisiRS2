import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/reservation.dart";
import "../../models/salon.dart";
import "../../providers/auth_provider.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../salon/salon_profile_screen.dart";
import "../salon/search_screen.dart";

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final api = context.read<ApiService>();
    final categories = await api.getCategories();
    final recs = await api.getRecommendations(take: 10);
    final salons = await api.getSalons(pageSize: 20);
    return _HomeData(categories.items, recs, salons.items);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  void _openSearch() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => const SearchScreen()));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.firstName ?? "";
    final initial =
        firstName.isNotEmpty ? firstName[0].toUpperCase() : "?";

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<_HomeData>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const LoadingView();
              }
              if (snap.hasError) {
                return ListView(children: [
                  const SizedBox(height: 200),
                  Center(child: Text("Greska: ${snap.error}")),
                ]);
              }
              final data = snap.data!;
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  // Pozdrav + avatar
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Dobro dosao,",
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 14)),
                            Text("$firstName 👋",
                                style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary,
                        child: Text(initial,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Pretraga
                  GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 15),
                      decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(14)),
                      child: const Row(children: [
                        Icon(Icons.search, color: AppColors.textSecondary),
                        SizedBox(width: 12),
                        Text("Pretrazi frizere, salone, usluge...",
                            style:
                                TextStyle(color: AppColors.textSecondary)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Kategorije - chipovi
                  _CategoryChips(categories: data.categories, onTap: _openSearch),
                  const SizedBox(height: 24),
                  // Preporuceni saloni
                  if (data.recommendations.isNotEmpty) ...[
                    _SectionHeader(
                        title: "Preporuceni saloni", onSeeAll: _openSearch),
                    const SizedBox(height: 12),
                    _RecommendedRow(data.recommendations),
                    const SizedBox(height: 24),
                  ],
                  // Najblize vama (u nedostatku geolokacije: svi saloni)
                  _SectionHeader(title: "Najblize vama", onSeeAll: _openSearch),
                  const SizedBox(height: 12),
                  ...data.salons.map((s) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SalonCard(salon: s),
                      )),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HomeData {
  final List<ServiceCategoryDto> categories;
  final List<RecommendationDto> recommendations;
  final List<SalonDto> salons;
  _HomeData(this.categories, this.recommendations, this.salons);
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onSeeAll;
  const _SectionHeader({required this.title, required this.onSeeAll});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onSeeAll,
          child: const Text("Vidi sve",
              style: TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<ServiceCategoryDto> categories;
  final VoidCallback onTap;
  const _CategoryChips({required this.categories, required this.onTap});

  IconData _icon(String? name) => switch (name) {
        "content_cut" => Icons.content_cut,
        "palette" => Icons.palette_outlined,
        "spa" => Icons.spa_outlined,
        "back_hand" => Icons.back_hand_outlined,
        "face" => Icons.face_outlined,
        _ => Icons.star_outline,
      };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // "Sve" chip (aktivan izgled)
          _chip(
            label: "Sve",
            icon: null,
            active: true,
            onTap: onTap,
          ),
          ...categories.map((c) => _chip(
                label: c.name,
                icon: _icon(c.iconName),
                active: false,
                onTap: onTap,
              )),
        ],
      ),
    );
  }

  Widget _chip(
      {required String label,
      IconData? icon,
      required bool active,
      required VoidCallback onTap}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon,
                    size: 16,
                    color:
                        active ? Colors.white : AppColors.primary),
                const SizedBox(width: 6),
              ],
              Text(label,
                  style: TextStyle(
                      color: active ? Colors.white : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontalne velike kartice preporucenih salona (kao na mockupu).
class _RecommendedRow extends StatelessWidget {
  final List<RecommendationDto> recs;
  const _RecommendedRow(this.recs);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 176,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: recs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final r = recs[i];
          return GestureDetector(
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => SalonProfileScreen(salonId: r.salonId))),
            child: SizedBox(
              width: 200,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // "Slika" salona (placeholder blok sa ikonom) + ocjena
                  Stack(
                    children: [
                      Container(
                        width: 200,
                        height: 110,
                        decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16)),
                        child: const Center(
                            child: Icon(Icons.store,
                                size: 40, color: AppColors.primary)),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.star,
                                size: 13, color: AppColors.pending),
                            const SizedBox(width: 2),
                            Text(r.averageRating.toStringAsFixed(1),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(r.salonName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(r.cityName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Kartica salona (koristi se i na drugim ekranima - npr. pretraga).
class SalonCard extends StatelessWidget {
  final SalonDto salon;
  const SalonCard({super.key, required this.salon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => SalonProfileScreen(salonId: salon.id))),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.store, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(salon.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on,
                        size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text("${salon.address} · ${salon.cityName}",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.star, size: 14, color: AppColors.pending),
                    const SizedBox(width: 4),
                    Text(
                        salon.reviewCount > 0
                            ? "${salon.averageRating.toStringAsFixed(1)} · ${salon.reviewCount} ocjena"
                            : "Nema recenzija",
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
