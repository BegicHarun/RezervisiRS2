import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/core.dart";
import "../../providers/auth_provider.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class HairdressersScreen extends StatefulWidget {
  const HairdressersScreen({super.key});
  @override
  State<HairdressersScreen> createState() => _HairdressersScreenState();
}

class _HairdressersScreenState extends State<HairdressersScreen> {
  List<HairdresserDto> _list = [];
  HairdresserDto? _selected;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await context.read<ApiService>().getHairdressers(pageSize: 100);
      setState(() {
        _list = res.items;
        _selected ??= _list.firstOrNull;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _addHairdresser() async {
    final salons = await context.read<ApiService>().getSalons(pageSize: 100);
    if (!mounted) return;
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _HairdresserAccountDialog(salons: salons.items),
    );
    if (created == true) {
      _selected = null;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader("Frizeri",
            subtitle: "Tim i raspolozivost (radno vrijeme)",
            action: (context.watch<AuthProvider>().user?.roles
                        .contains("Administrator") ??
                    false)
                ? ElevatedButton.icon(
                    onPressed: _addHairdresser,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text("Dodaj frizera"))
                : null),
        const SizedBox(height: 20),
        Expanded(
          child: _loading
              ? const LoadingView()
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Lista
                    SizedBox(
                      width: 280,
                      child: Container(
                        decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border)),
                        child: _list.isEmpty
                            ? const EmptyView("Nema frizera")
                            : ListView.builder(
                                itemCount: _list.length,
                                itemBuilder: (context, i) {
                                  final h = _list[i];
                                  final sel = _selected?.id == h.id;
                                  return ListTile(
                                    selected: sel,
                                    selectedTileColor:
                                        AppColors.primary.withValues(alpha: 0.08),
                                    leading: CircleAvatar(
                                      backgroundColor:
                                          AppColors.primary.withValues(alpha: 0.1),
                                      child: Text(
                                          h.fullName.isNotEmpty
                                              ? h.fullName[0]
                                              : "?",
                                          style: const TextStyle(
                                              color: AppColors.primary)),
                                    ),
                                    title: Text(h.fullName),
                                    subtitle: Text(h.specialization),
                                    trailing: _statusDot(h.verificationStatus),
                                    onTap: () => setState(() => _selected = h),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Detalj
                    Expanded(
                      child: _selected == null
                          ? const Center(child: EmptyView("Odaberite frizera"))
                          : _HairdresserDetail(
                              key: ValueKey(_selected!.id),
                              hairdresser: _selected!),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _statusDot(String status) {
    final color = switch (status) {
      "Approved" => AppColors.completed,
      "Pending" => AppColors.pending,
      "Rejected" => AppColors.cancelled,
      _ => AppColors.textSecondary,
    };
    return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _HairdresserDetail extends StatefulWidget {
  final HairdresserDto hairdresser;
  const _HairdresserDetail({super.key, required this.hairdresser});
  @override
  State<_HairdresserDetail> createState() => _HairdresserDetailState();
}

class _HairdresserDetailState extends State<_HairdresserDetail> {
  List<WorkingHourDto> _hours = [];
  bool _loading = false;
  bool _saving = false;

  static const _dayNames = [
    "Ponedjeljak", "Utorak", "Srijeda", "Cetvrtak", "Petak", "Subota", "Nedjelja"
  ];
  // mapiranje na DayOfWeek (0=ned..6=sub)
  static const _dayOrder = [1, 2, 3, 4, 5, 6, 0];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final existing = await context
          .read<ApiService>()
          .getWorkingHours(widget.hairdresser.id);
      // Napravi punu sedmicu (pon-ned), popuni postojecim.
      final map = {for (final w in existing) w.dayOfWeek: w};
      _hours = _dayOrder.map((dow) {
        final e = map[dow];
        return e ??
            WorkingHourDto(
                id: 0,
                dayOfWeek: dow,
                dayName: _dayNames[_dayOrder.indexOf(dow)],
                startTime: "09:00",
                endTime: "17:00",
                isDayOff: true);
      }).toList();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final body = _hours
          .map((w) => {
                "dayOfWeek": w.dayOfWeek,
                "startTime": w.startTime,
                "endTime": w.endTime,
                "isDayOff": w.isDayOff,
              })
          .toList();
      await context
          .read<ApiService>()
          .setWorkingHours(widget.hairdresser.id, body);
      if (mounted) showOk(context, "Radno vrijeme sacuvano.");
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final parts = (isStart ? _hours[index].startTime : _hours[index].endTime)
        .split(":");
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 9,
          minute: int.tryParse(parts.length > 1 ? parts[1] : "0") ?? 0),
    );
    if (picked == null) return;
    final str =
        "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
    setState(() {
      final w = _hours[index];
      _hours[index] = WorkingHourDto(
        id: w.id,
        dayOfWeek: w.dayOfWeek,
        dayName: w.dayName,
        startTime: isStart ? str : w.startTime,
        endTime: isStart ? w.endTime : str,
        isDayOff: w.isDayOff,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hairdresser;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                child: Text(h.fullName.isNotEmpty ? h.fullName[0] : "?",
                    style: const TextStyle(
                        fontSize: 22, color: AppColors.primary)),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(h.fullName,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  Text("${h.specialization} · ${h.salonName}",
                      style: const TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text("Radno vrijeme",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const LoadingView()
                : ListView.builder(
                    itemCount: _hours.length,
                    itemBuilder: (context, i) {
                      final w = _hours[i];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 110,
                                child: Text(_dayNames[i],
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w500))),
                            Switch(
                              value: !w.isDayOff,
                              onChanged: (on) => setState(() {
                                _hours[i] = WorkingHourDto(
                                  id: w.id,
                                  dayOfWeek: w.dayOfWeek,
                                  dayName: w.dayName,
                                  startTime: w.startTime,
                                  endTime: w.endTime,
                                  isDayOff: !on,
                                );
                              }),
                            ),
                            const SizedBox(width: 8),
                            if (!w.isDayOff) ...[
                              _timeChip(w.startTime, () => _pickTime(i, true)),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text("-"),
                              ),
                              _timeChip(w.endTime, () => _pickTime(i, false)),
                            ] else
                              const Text("Neradni dan",
                                  style: TextStyle(
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? "Cuvanje..." : "Sacuvaj radno vrijeme"),
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeChip(String time, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
          side: const BorderSide(color: AppColors.border)),
      child: Text(time),
    );
  }
}

class _HairdresserAccountDialog extends StatefulWidget {
  final List<SalonDto> salons;
  const _HairdresserAccountDialog({required this.salons});
  @override
  State<_HairdresserAccountDialog> createState() =>
      _HairdresserAccountDialogState();
}

class _HairdresserAccountDialogState
    extends State<_HairdresserAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _specialization = TextEditingController();
  int? _salonId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _salonId = widget.salons.firstOrNull?.id;
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _specialization.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_salonId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().createHairdresserWithAccount({
        "firstName": _firstName.text.trim(),
        "lastName": _lastName.text.trim(),
        "username": _username.text.trim(),
        "email": _email.text.trim(),
        "password": _password.text,
        "specialization": _specialization.text.trim(),
        "salonId": _salonId,
      });
      if (mounted) {
        showOk(context, "Frizer kreiran. Moze se prijaviti svojim kredencijalima.");
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Dodaj frizera (sa nalogom)"),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(labelText: "Ime"),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "Obavezno" : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: "Prezime"),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? "Obavezno" : null,
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _salonId,
                  decoration: const InputDecoration(labelText: "Salon"),
                  items: widget.salons
                      .map((s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _salonId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _specialization,
                  decoration:
                      const InputDecoration(labelText: "Specijalizacija"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Obavezno" : null,
                ),
                const Divider(height: 28),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text("Podaci za prijavu",
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _username,
                  decoration:
                      const InputDecoration(labelText: "Korisnicko ime"),
                  validator: (v) => (v == null || v.length < 3)
                      ? "Najmanje 3 karaktera"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (v) => (v == null || !v.contains("@"))
                      ? "Neispravan email"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  decoration: const InputDecoration(labelText: "Lozinka"),
                  validator: (v) =>
                      (v == null || v.length < 6) ? "Najmanje 6 karaktera" : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Odustani")),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text("Kreiraj"),
        ),
      ],
    );
  }
}
