import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/core.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../verification/verification_screen.dart" show StatusChip;

class SalonsScreen extends StatefulWidget {
  const SalonsScreen({super.key});
  @override
  State<SalonsScreen> createState() => _SalonsScreenState();
}

class _SalonsScreenState extends State<SalonsScreen> {
  List<SalonDto> _salons = [];
  List<CityDto> _cities = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      if (_cities.isEmpty) _cities = (await api.getCities()).items;
      _salons = (await api.getSalons(pageSize: 100)).items;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({SalonDto? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SalonDialog(existing: existing, cities: _cities),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(SalonDto s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Brisanje salona"),
        content: Text("Obrisati salon \"${s.name}\"?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Odustani")),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.cancelled),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Obrisi")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await context.read<ApiService>().deleteSalon(s.id);
      if (mounted) showOk(context, "Salon obrisan.");
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
        PageHeader("Saloni",
            subtitle: "Upravljanje salonima",
            action: ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text("Novi salon"))),
        const SizedBox(height: 20),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: _loading
                ? const LoadingView()
                : _salons.isEmpty
                    ? const EmptyView("Nema salona")
                    : SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor:
                                WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text("Naziv")),
                              DataColumn(label: Text("Adresa")),
                              DataColumn(label: Text("Grad")),
                              DataColumn(label: Text("Status")),
                              DataColumn(label: Text("Ocjena")),
                              DataColumn(label: Text("Akcije")),
                            ],
                            rows: _salons
                                .map((s) => DataRow(cells: [
                                      DataCell(Text(s.name)),
                                      DataCell(Text(s.address)),
                                      DataCell(Text(s.cityName)),
                                      DataCell(StatusChip(s.verificationStatus)),
                                      DataCell(Text(s.reviewCount > 0
                                          ? "${s.averageRating.toStringAsFixed(1)} (${s.reviewCount})"
                                          : "-")),
                                      DataCell(Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                              icon: const Icon(Icons.edit_outlined, size: 20),
                                              onPressed: () => _edit(existing: s)),
                                          IconButton(
                                              icon: const Icon(Icons.delete_outline,
                                                  size: 20, color: AppColors.cancelled),
                                              onPressed: () => _delete(s)),
                                        ],
                                      )),
                                    ]))
                                .toList(),
                          ),
                        ),
                      ),
          ),
        ),
      ],
    );
  }
}

class _SalonDialog extends StatefulWidget {
  final SalonDto? existing;
  final List<CityDto> cities;
  const _SalonDialog({this.existing, required this.cities});
  @override
  State<_SalonDialog> createState() => _SalonDialogState();
}

class _SalonDialogState extends State<_SalonDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _address;
  late TextEditingController _desc;
  int? _cityId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? "");
    _address = TextEditingController(text: e?.address ?? "");
    _desc = TextEditingController(text: e?.description ?? "");
    _cityId = e?.cityId ?? widget.cities.firstOrNull?.id;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_cityId == null) return;
    setState(() => _saving = true);
    final body = {
      "name": _name.text.trim(),
      "address": _address.text.trim(),
      "description": _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      "cityId": _cityId,
    };
    try {
      final api = context.read<ApiService>();
      if (widget.existing == null) {
        await api.createSalon(body);
      } else {
        await api.updateSalon(widget.existing!.id, body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? "Novi salon" : "Uredi salon"),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: "Naziv"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Obavezno" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration: const InputDecoration(labelText: "Adresa"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Obavezno" : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: _cityId,
                  decoration: const InputDecoration(labelText: "Grad"),
                  items: widget.cities
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _cityId = v),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: "Opis"),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text("Odustani")),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text("Sacuvaj"),
        ),
      ],
    );
  }
}
