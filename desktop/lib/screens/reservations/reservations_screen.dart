import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:intl/intl.dart";
import "../../models/core.dart";
import "../../models/dashboard.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ReservationsScreen extends StatefulWidget {
  const ReservationsScreen({super.key});
  @override
  State<ReservationsScreen> createState() => _ReservationsScreenState();
}

class _ReservationsScreenState extends State<ReservationsScreen> {
  String? _status;
  String _search = "";
  int _page = 1;
  final int _pageSize = 10;
  PagedResult<ReservationDto>? _data;
  bool _loading = false;

  final _statuses = const [
    ("Sve", null),
    ("Na cekanju", "Pending"),
    ("Potvrdjeno", "Confirmed"),
    ("Zavrseno", "Completed"),
    ("Otkazano", "Cancelled"),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<ApiService>().getReservations(
          page: _page,
          pageSize: _pageSize,
          status: _status,
          search: _search.isEmpty ? null : _search);
      setState(() => _data = res);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _act(ReservationDto r, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return; // otkazano
    }
    try {
      await context.read<ApiService>().changeStatus(
          r.id, approve ? "Confirmed" : "Cancelled",
          reason: reason);
      if (mounted) showOk(context, approve ? "Rezervacija potvrdjena." : "Rezervacija odbijena.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _complete(ReservationDto r) async {
    try {
      await context.read<ApiService>().changeStatus(r.id, "Completed");
      if (mounted) showOk(context, "Rezervacija zavrsena.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<String?> _askReason() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Razlog odbijanja"),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: "Obavezno unesite razlog"),
          maxLines: 2,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Odustani")),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.cancelled),
            onPressed: () {
              if (c.text.trim().isEmpty) return;
              Navigator.pop(ctx, c.text.trim());
            },
            child: const Text("Odbij"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader("Rezervacije",
            subtitle: "Pregled i upravljanje svim rezervacijama"),
        const SizedBox(height: 20),
        // Filteri
        Row(
          children: [
            ..._statuses.map((s) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s.$1),
                    selected: _status == s.$2,
                    onSelected: (_) {
                      setState(() {
                        _status = s.$2;
                        _page = 1;
                      });
                      _load();
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  ),
                )),
            const Spacer(),
            SizedBox(
              width: 260,
              child: TextField(
                decoration: const InputDecoration(
                    hintText: "Pretraga (klijent/usluga)...",
                    prefixIcon: Icon(Icons.search)),
                onSubmitted: (v) {
                  setState(() {
                    _search = v;
                    _page = 1;
                  });
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Tabela
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: _loading
                ? const LoadingView()
                : _data == null || _data!.items.isEmpty
                    ? const EmptyView("Nema rezervacija")
                    : Column(
                        children: [
                          Expanded(child: _table()),
                          _pager(),
                        ],
                      ),
          ),
        ),
      ],
    );
  }

  Widget _table() {
    final df = DateFormat("dd.MM.yyyy HH:mm");
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SizedBox(
        width: double.infinity,
        child: DataTable(
          columnSpacing: 24,
          headingRowColor:
              WidgetStateProperty.all(AppColors.background),
          columns: const [
            DataColumn(label: Text("Klijent")),
            DataColumn(label: Text("Usluga")),
            DataColumn(label: Text("Frizer")),
            DataColumn(label: Text("Termin")),
            DataColumn(label: Text("Cijena")),
            DataColumn(label: Text("Status")),
            DataColumn(label: Text("Odobrio / razlog")),
            DataColumn(label: Text("Akcije")),
          ],
          rows: _data!.items.map((r) {
            return DataRow(cells: [
              DataCell(Text(r.clientName)),
              DataCell(Text(r.serviceName)),
              DataCell(Text(r.hairdresserName)),
              DataCell(Text(df.format(r.startTime))),
              DataCell(Text("${r.price.toStringAsFixed(2)} KM")),
              DataCell(StatusBadge(r.status)),
              DataCell(SizedBox(
                width: 200,
                child: Text(r.auditSummary ?? "-",
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12)),
              )),
              DataCell(_actions(r)),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _actions(ReservationDto r) {
    if (r.status == "Pending") {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        IconButton(
            tooltip: "Potvrdi",
            icon: const Icon(Icons.check_circle_outline,
                color: AppColors.completed),
            onPressed: () => _act(r, true)),
        IconButton(
            tooltip: "Odbij",
            icon: const Icon(Icons.cancel_outlined, color: AppColors.cancelled),
            onPressed: () => _act(r, false)),
      ]);
    }
    if (r.status == "Confirmed") {
      return Row(mainAxisSize: MainAxisSize.min, children: [
        TextButton(
            onPressed: () => _complete(r), child: const Text("Zavrsi")),
        IconButton(
            tooltip: "Otkazi",
            icon: const Icon(Icons.cancel_outlined, color: AppColors.cancelled),
            onPressed: () => _act(r, false)),
      ]);
    }
    return const Text("-", style: TextStyle(color: AppColors.textSecondary));
  }

  Widget _pager() {
    final d = _data!;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text("Ukupno: ${d.totalCount}",
              style: const TextStyle(color: AppColors.textSecondary)),
          Row(
            children: [
              IconButton(
                onPressed: d.page > 1
                    ? () {
                        setState(() => _page--);
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text("Strana ${d.page} / ${d.totalPages == 0 ? 1 : d.totalPages}"),
              IconButton(
                onPressed: d.page < d.totalPages
                    ? () {
                        setState(() => _page++);
                        _load();
                      }
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
