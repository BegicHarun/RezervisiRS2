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
  int _request = 0;
  Object? _error;

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return _dayOffset(date, 1 - date.weekday);
  }

  static DateTime _dayOffset(DateTime date, int days) =>
      DateTime(date.year, date.month, date.day + days);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    final from = _weekStart;
    final hairdresser = _hairdresserId;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final reservations = <int, ReservationDto>{};
      final staff = <HairdresserDto>[..._hairdressers];
      if (staff.isEmpty) {
        for (var page = 1; mounted && request == _request; page++) {
          final result = await api.getHairdressers(page: page, pageSize: 100);
          staff.addAll(result.items);
          if (page >= result.totalPages) break;
        }
      }
      for (var page = 1; mounted && request == _request; page++) {
        final result = await api.getReservations(
          page: page,
          pageSize: 100,
          from: from,
          to: _dayOffset(from, 7),
          hairdresserId: hairdresser,
        );
        for (final item in result.items) {
          reservations[item.id] = item;
        }
        if (page >= result.totalPages) break;
      }
      if (!mounted || request != _request) return;
      _hairdressers = staff;
      _all = reservations.values.toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
    } catch (error) {
      if (mounted && request == _request) _error = error;
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  void _selectWeek(DateTime start) {
    _weekStart = start;
    _load();
  }

  List<ReservationDto> _forCell(DateTime day, int hour) {
    final start = DateTime(day.year, day.month, day.day, hour);
    final end = DateTime(day.year, day.month, day.day, hour + 1);
    return _all
        .where((reservation) =>
            reservation.startTime.isBefore(end) &&
            reservation.endTime.isAfter(start))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(7, (i) => _dayOffset(_weekStart, i));
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
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: "Frizer"),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text("Svi frizeri")),
                      ..._hairdressers.map((h) => DropdownMenuItem(
                          value: h.id,
                          child: Text(h.fullName,
                              overflow: TextOverflow.ellipsis))),
                    ],
                    onChanged: (v) {
                      _hairdresserId = v;
                      _load();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                    onPressed: () => _selectWeek(_dayOffset(_weekStart, -7)),
                    icon: const Icon(Icons.chevron_left)),
                TextButton(
                    onPressed: () => _selectWeek(_mondayOf(DateTime.now())),
                    child: const Text("Danas")),
                IconButton(
                    onPressed: () => _selectWeek(_dayOffset(_weekStart, 7)),
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
                : _error != null
                    ? Center(
                        child: TextButton(
                            onPressed: _load,
                            child: Text("Pokušaj ponovo: $_error")))
                    : Column(
                        children: [
                          // Header sa danima
                          Row(
                            children: [
                              const SizedBox(width: 60),
                              for (int i = 0; i < 7; i++)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                    alignment: Alignment.center,
                                    child: Column(
                                      children: [
                                        Text(dayNames[i],
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        Text(df.format(days[i]),
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color:
                                                    AppColors.textSecondary)),
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
                                  for (int hour = 0; hour < 24; hour++)
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
                  children: _forCell(day, hour).map((r) => _slot(r)).toList(),
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
              style:
                  const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          Text(r.clientName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textSecondary)),
        ],
      ),
    );
  }

  Widget _legend() {
    Widget item(String status) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
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
