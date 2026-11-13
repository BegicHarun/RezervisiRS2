import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/core.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});
  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<SalonDto> _salons = [];
  List<HairdresserDto> _hairdressers = [];
  bool _loading = false;
  String _search = "";
  int _request = 0;
  int _page = 1;
  int _salonPages = 0;
  int _staffPages = 0;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final request = ++_request;
    final search = _search;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final (salons, hairdressers) = await (
        api.getSalons(page: _page, pageSize: 25, search: search),
        api.getHairdressers(page: _page, pageSize: 25, search: search),
      ).wait;
      if (!mounted || request != _request) return;
      _salonPages = salons.totalPages;
      _staffPages = hairdressers.totalPages;
      _salons = salons.items;
      _hairdressers = hairdressers.items;
    } catch (e) {
      if (mounted && request == _request) _error = e;
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  Future<String?> _askReason() =>
      showReasonDialog(context, "Razlog odbijanja", "Odbij");

  Future<void> _verifySalon(SalonDto s, bool approve) async {
    if (_saving) return;
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (!mounted || reason == null) return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context
          .read<ApiService>()
          .verifySalon(s.id, approve, reason: reason);
      if (mounted) {
        showOk(context, approve ? "Salon odobren." : "Salon odbijen.");
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _verifyHairdresser(HairdresserDto h, bool approve) async {
    if (_saving) return;
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (!mounted || reason == null) return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await context
          .read<ApiService>()
          .verifyHairdresser(h.id, approve, reason: reason);
      if (mounted) {
        showOk(context, approve ? "Frizer odobren." : "Frizer odbijen.");
      }
      if (mounted) _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader("Verifikacija",
            subtitle: "Odobravanje salona i frizera"),
        const SizedBox(height: 16),
        ListSearch(onSearch: (value) {
          _page = 1;
          _search = value;
          _load();
        }),
        TabBar(
          controller: _tab,
          onTap: (_) {
            _page = 1;
            _load();
          },
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: "Saloni"), Tab(text: "Frizeri")],
        ),
        const SizedBox(height: 16),
        ListPages(
            page: _page,
            totalPages: _tab.index == 0 ? _salonPages : _staffPages,
            loading: _loading || _saving,
            onPage: (page) {
              _page = page;
              _load();
            }),
        Expanded(
          child: _loading
              ? const LoadingView()
              : _error != null
                  ? Center(
                      child: TextButton(
                          onPressed: _load,
                          child: Text("Pokušaj ponovo: $_error")))
                  : TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _tab,
                      children: [
                        _salonList(),
                        _hairdresserList(),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _salonList() {
    final groups = _group(_salons.map((s) => s.verificationStatus));
    return ListView(
      children: [
        for (final status in ["Pending", "Approved", "Rejected"])
          if (_salons.any((s) => s.verificationStatus == status)) ...[
            _groupHeader(status, groups[status] ?? 0),
            ..._salons
                .where((s) => s.verificationStatus == status)
                .map((s) => _salonCard(s)),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Widget _hairdresserList() {
    final groups = _group(_hairdressers.map((h) => h.verificationStatus));
    return ListView(
      children: [
        for (final status in ["Pending", "Approved", "Rejected"])
          if (_hairdressers.any((h) => h.verificationStatus == status)) ...[
            _groupHeader(status, groups[status] ?? 0),
            ..._hairdressers
                .where((h) => h.verificationStatus == status)
                .map((h) => _hairdresserCard(h)),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  Map<String, int> _group(Iterable<String> statuses) {
    final m = <String, int>{};
    for (final s in statuses) {
      m[s] = (m[s] ?? 0) + 1;
    }
    return m;
  }

  Widget _groupHeader(String status, int count) {
    final label = switch (status) {
      "Pending" => "Na cekanju",
      "Approved" => "Odobreno",
      "Rejected" => "Odbijeno",
      _ => status,
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text("$label ($count)",
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
    );
  }

  Widget _salonCard(SalonDto s) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.store, color: AppColors.primary),
        title: Text(s.name),
        subtitle: Text("${s.address}, ${s.cityName}"),
        trailing: _actions(s.verificationStatus, () => _verifySalon(s, true),
            () => _verifySalon(s, false)),
      ),
    );
  }

  Widget _hairdresserCard(HairdresserDto h) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.person, color: AppColors.primary),
        title: Text(h.fullName),
        subtitle: Text("${h.specialization} · ${h.salonName}"),
        trailing: _actions(
            h.verificationStatus,
            () => _verifyHairdresser(h, true),
            () => _verifyHairdresser(h, false)),
      ),
    );
  }

  Widget _actions(String status, VoidCallback approve, VoidCallback reject) {
    if (status != "Pending") {
      return StatusChip(status);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          onPressed: _saving ? null : approve,
          icon: const Icon(Icons.check, color: AppColors.completed, size: 18),
          label: const Text("Odobri",
              style: TextStyle(color: AppColors.completed)),
        ),
        TextButton.icon(
          onPressed: _saving ? null : reject,
          icon: const Icon(Icons.close, color: AppColors.cancelled, size: 18),
          label:
              const Text("Odbij", style: TextStyle(color: AppColors.cancelled)),
        ),
      ],
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      "Approved" => (AppColors.completed, "Odobreno"),
      "Rejected" => (AppColors.cancelled, "Odbijeno"),
      _ => (AppColors.pending, "Na cekanju"),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
