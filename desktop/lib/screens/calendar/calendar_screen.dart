import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/core.dart";
import "../../models/dashboard.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _weekStart = _mondayOf(DateTime.now());
  List<ReservationDto> _all = [];
  List<HairdresserDto> _hairdressers = [];
  int? _hairdresserId;
  bool _loading = false;

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: (date.weekday + 6) % 7));
  }

  static const int startHour = 8;
  static const int endHour = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      if (_hairdressers.isEmpty) {
        final hd = await api.getHairdressers(pageSize: 100);
        _hairdressers = hd.items;
      }
      // Uzmi sve rezervacije (dovoljno velik pageSize za demo).
      final res = await api.getReservations(pageSize: 100);
      _all = res.items;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ReservationDto> _forCell(DateTime day, int hour) {
    return _all.where((r) {
      if (_hairdresserId != null && r.hairdresserId != _hairdresserId) {
        return false;
      }
      return r.startTime.year == day.year &&
          r.startTime.month == day.month &&
          r.startTime.day == day.day &&
          r.startTime.hour == hour;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _weekStart.add(Duration(days: i)));
    final df = DateFormat("dd.MM");
    const dayNames = ["Pon", "Uto", "Sri", "Cet", "Pet", "Sub", "Ned"];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader("Sedmicni kalendar",
            subtitle: "Termini po danima i satima",
            action: Row(
              children: [
                // Filter frizera
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<int?>(
                    initialValue: _hairdresserId,
                    decoration: const InputDecoration(labelText: "Frizer"),
                    items: [
                      const DropdownMenuItem(value: null, child: Text("Svi frizeri")),
                      ..._hairdressers.map((h) =>
                          DropdownMenuItem(value: h.id, child: Text(h.fullName))),
                    ],
                    onChanged: (v) => setState(() => _hairdresserId = v),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                    onPressed: () => setState(() =>
                        _weekStart = _weekStart.subtract(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_left)),
                TextButton(
                    onPressed: () =>
                        setState(() => _weekStart = _mondayOf(DateTime.now())),
                    child: const Text("Danas")),
                IconButton(
                    onPressed: () => setState(() =>
                        _weekStart = _weekStart.add(const Duration(days: 7))),
                    icon: const Icon(Icons.chevron_right)),
              ],
            )),
        const SizedBox(height: 12),
        _legend(),
        const SizedBox(height: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: _loading
                ? const LoadingView()
                : Column(
                    children: [
                      // Header sa danima
                      Row(
                        children: [
                          const SizedBox(width: 60),
                          for (int i = 0; i < 7; i++)
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Text(dayNames[i],
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    Text(df.format(days[i]),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.textSecondary)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Divider(height: 1),
                      // Grid sati
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            children: [
                              for (int hour = startHour; hour < endHour; hour++)
                                _hourRow(hour, days),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _hourRow(int hour, List<DateTime> days) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60,
            child: Padding(
              padding: const EdgeInsets.only(top: 6, right: 6),
              child: Text("${hour.toString().padLeft(2, '0')}:00",
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ),
          ),
          for (final day in days)
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minHeight: 44),
                decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(6)),
                child: Column(
                  children: _forCell(day, hour)
                      .map((r) => _slot(r))
                      .toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _slot(ReservationDto r) {
    final color = AppColors.forStatus(r.status);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border(left: BorderSide(color: color, width: 3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(r.serviceName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(r.clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(String status) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                  color: AppColors.forStatus(status),
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text(AppColors.statusLabel(status),
              style: const TextStyle(fontSize: 12)),
        ]);
    return Row(
      children: [
        item("Pending"),
        const SizedBox(width: 16),
        item("Confirmed"),
        const SizedBox(width: 16),
        item("Completed"),
        const SizedBox(width: 16),
        item("Cancelled"),
      ],
    );
  }
}
