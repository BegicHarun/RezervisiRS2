import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:fl_chart/fl_chart.dart";
import "package:intl/intl.dart";
import "../../models/dashboard.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardDto> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<ApiService>().getDashboard();
  }

  void _reload() {
  setState(() {
    _future = context.read<ApiService>().getDashboard();
  });
}

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardDto>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        if (snap.hasError) {
          return Center(child: Text("Greska: ${snap.error}"));
        }
        final d = snap.data!;
        return ListView(
          children: [
            PageHeader("Dashboard",
                subtitle: "Presjek poslovanja",
                action: IconButton(
                    onPressed: _reload, icon: const Icon(Icons.refresh))),
            const SizedBox(height: 20),
            // KPI kartice
            Row(
              children: [
                KpiCard(
                    label: "Rezervacije",
                    value: "${d.totalReservations}",
                    icon: Icons.event_note,
                    trend: d.reservationsTrend),
                const SizedBox(width: 16),
                KpiCard(
                    label: "Prihod",
                    value: "${d.totalRevenue.toStringAsFixed(0)} KM",
                    icon: Icons.payments_outlined,
                    trend: d.revenueTrend),
                const SizedBox(width: 16),
                KpiCard(
                    label: "Novi klijenti",
                    value: "${d.newClients}",
                    icon: Icons.person_add_outlined),
                const SizedBox(width: 16),
                KpiCard(
                    label: "Popunjenost",
                    value: "${d.occupancyRate.toStringAsFixed(0)}%",
                    icon: Icons.donut_large),
              ],
            ),
            const SizedBox(height: 20),
            // Grafovi
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ChartCard(
                      title: "Rezervacije po danu (7 dana)",
                      child: _BarChart(d.reservationsPerDay),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _ChartCard(
                      title: "Po statusu",
                      child: _DonutChart(d.reservationsByStatus),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Nedavne + popularne
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ChartCard(
                      title: "Nedavne rezervacije",
                      child: _RecentList(d.recentReservations),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _ChartCard(
                      title: "Popularne usluge",
                      child: _PopularList(d.popularServices),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<DailyCount> data;
  const _BarChart(this.data);
  @override
  Widget build(BuildContext context) {
    final maxY = (data.isEmpty
            ? 1
            : data.map((e) => e.count).reduce((a, b) => a > b ? a : b))
        .toDouble();
    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: (maxY < 4 ? 4 : maxY) + 1,
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= data.length) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(data[i].label,
                        style: const TextStyle(fontSize: 11)),
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (int i = 0; i < data.length; i++)
              BarChartGroupData(x: i, barRods: [
                BarChartRodData(
                  toY: data[i].count.toDouble(),
                  color: AppColors.primary,
                  width: 22,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _DonutChart extends StatelessWidget {
  final List<StatusCount> data;
  const _DonutChart(this.data);
  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (s, e) => s + e.count);
    final withData = data.where((e) => e.count > 0).toList();
    return SizedBox(
      height: 220,
      child: total == 0
          ? const EmptyView("Nema podataka", icon: Icons.pie_chart_outline)
          : Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 45,
                      sections: withData
                          .map((e) => PieChartSectionData(
                                value: e.count.toDouble(),
                                color: AppColors.forStatus(e.status),
                                title: "${e.count}",
                                radius: 45,
                                titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: withData
                      .map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                        color:
                                            AppColors.forStatus(e.status),
                                        borderRadius:
                                            BorderRadius.circular(2))),
                                const SizedBox(width: 6),
                                Text(AppColors.statusLabel(e.status),
                                    style: const TextStyle(fontSize: 12)),
                              ],
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(width: 8),
              ],
            ),
    );
  }
}

class _RecentList extends StatelessWidget {
  final List<ReservationDto> items;
  const _RecentList(this.items);
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(
          height: 180, child: EmptyView("Nema rezervacija"));
    }
    final df = DateFormat("dd.MM. HH:mm");
    return Column(
      children: items
          .map((r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.clientName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                          Text(r.serviceName,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(df.format(r.startTime),
                          style: const TextStyle(fontSize: 12)),
                    ),
                    StatusBadge(r.status),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _PopularList extends StatelessWidget {
  final List<PopularService> items;
  const _PopularList(this.items);
  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox(height: 180, child: EmptyView("Nema podataka"));
    }
    return Column(
      children: [
        for (int i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text("${i + 1}",
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary)),
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(items[i].serviceName,
                        maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text("${items[i].reservationCount}x",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
      ],
    );
  }
}
