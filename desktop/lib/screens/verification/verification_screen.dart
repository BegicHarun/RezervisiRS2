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
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      _salons = (await api.getSalons(pageSize: 100)).items;
      _hairdressers = (await api.getHairdressers(pageSize: 100)).items;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
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
            maxLines: 2,
            decoration: const InputDecoration(hintText: "Obavezno obrazlozenje")),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Odustani")),
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

  Future<void> _verifySalon(SalonDto s, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    try {
      await context.read<ApiService>().verifySalon(s.id, approve, reason: reason);
      if (mounted) showOk(context, approve ? "Salon odobren." : "Salon odbijen.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _verifyHairdresser(HairdresserDto h, bool approve) async {
    String? reason;
    if (!approve) {
      reason = await _askReason();
      if (reason == null) return;
    }
    try {
      await context
          .read<ApiService>()
          .verifyHairdresser(h.id, approve, reason: reason);
      if (mounted) showOk(context, approve ? "Frizer odobren." : "Frizer odbijen.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
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
        TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          tabs: const [Tab(text: "Saloni"), Tab(text: "Frizeri")],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const LoadingView()
              : TabBarView(
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
        trailing: _actions(s.verificationStatus,
            () => _verifySalon(s, true), () => _verifySalon(s, false)),
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
        trailing: _actions(h.verificationStatus,
            () => _verifyHairdresser(h, true), () => _verifyHairdresser(h, false)),
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
          onPressed: approve,
          icon: const Icon(Icons.check, color: AppColors.completed, size: 18),
          label: const Text("Odobri",
              style: TextStyle(color: AppColors.completed)),
        ),
        TextButton.icon(
          onPressed: reject,
          icon: const Icon(Icons.close, color: AppColors.cancelled, size: 18),
          label: const Text("Odbij",
              style: TextStyle(color: AppColors.cancelled)),
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
