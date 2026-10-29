import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/core.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});
  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  List<ServiceDto> _services = [];
  List<ServiceCategoryDto> _categories = [];
  List<SalonDto> _salons = [];
  int? _filterCategory;
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
      if (_categories.isEmpty) _categories = (await api.getCategories()).items;
      if (_salons.isEmpty) _salons = (await api.getSalons()).items;
      final res = await api.getServices(categoryId: _filterCategory);
      _services = res.items;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit({ServiceDto? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ServiceDialog(
          existing: existing, categories: _categories, salons: _salons),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(ServiceDto s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Brisanje usluge"),
        content: Text("Obrisati uslugu \"${s.name}\"?"),
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
      await context.read<ApiService>().deleteService(s.id);
      if (mounted) showOk(context, "Usluga obrisana.");
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
        PageHeader("Usluge i cijene",
            subtitle: "Katalog usluga salona",
            action: ElevatedButton.icon(
                onPressed: () => _edit(),
                icon: const Icon(Icons.add),
                label: const Text("Nova usluga"))),
        const SizedBox(height: 20),
        Row(
          children: [
            SizedBox(
              width: 220,
              child: DropdownButtonFormField<int?>(
                initialValue: _filterCategory,
                decoration: const InputDecoration(labelText: "Kategorija"),
                items: [
                  const DropdownMenuItem(value: null, child: Text("Sve kategorije")),
                  ..._categories.map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
                ],
                onChanged: (v) {
                  setState(() => _filterCategory = v);
                  _load();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border)),
            child: _loading
                ? const LoadingView()
                : _services.isEmpty
                    ? const EmptyView("Nema usluga")
                    : SingleChildScrollView(
                        child: SizedBox(
                          width: double.infinity,
                          child: DataTable(
                            columnSpacing: 24,
                            headingRowColor:
                                WidgetStateProperty.all(AppColors.background),
                            columns: const [
                              DataColumn(label: Text("Naziv")),
                              DataColumn(label: Text("Kategorija")),
                              DataColumn(label: Text("Trajanje")),
                              DataColumn(label: Text("Cijena")),
                              DataColumn(label: Text("Aktivna")),
                              DataColumn(label: Text("Akcije")),
                            ],
                            rows: _services
                                .map((s) => DataRow(cells: [
                                      DataCell(Text(s.name)),
                                      DataCell(Text(s.serviceCategoryName)),
                                      DataCell(Text("${s.durationMinutes} min")),
                                      DataCell(Text("${s.price.toStringAsFixed(2)} KM")),
                                      DataCell(Icon(
                                          s.isActive
                                              ? Icons.check_circle
                                              : Icons.remove_circle_outline,
                                          color: s.isActive
                                              ? AppColors.completed
                                              : AppColors.textSecondary,
                                          size: 20)),
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

class _ServiceDialog extends StatefulWidget {
  final ServiceDto? existing;
  final List<ServiceCategoryDto> categories;
  final List<SalonDto> salons;
  const _ServiceDialog(
      {this.existing, required this.categories, required this.salons});
  @override
  State<_ServiceDialog> createState() => _ServiceDialogState();
}

class _ServiceDialogState extends State<_ServiceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _desc;
  late TextEditingController _price;
  late TextEditingController _duration;
  int? _categoryId;
  int? _salonId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? "");
    _desc = TextEditingController(text: e?.description ?? "");
    _price = TextEditingController(text: e?.price.toString() ?? "");
    _duration = TextEditingController(text: e?.durationMinutes.toString() ?? "30");
    _categoryId = e?.serviceCategoryId ?? widget.categories.firstOrNull?.id;
    _salonId = e?.salonId ?? widget.salons.firstOrNull?.id;
    _active = e?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _duration.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null || _salonId == null) return;
    setState(() => _saving = true);
    final body = {
      "name": _name.text.trim(),
      "description": _desc.text.trim(),
      "price": double.tryParse(_price.text.replaceAll(",", ".")) ?? 0,
      "durationMinutes": int.tryParse(_duration.text) ?? 30,
      "salonId": _salonId,
      "serviceCategoryId": _categoryId,
      "isActive": _active,
    };
    try {
      final api = context.read<ApiService>();
      if (widget.existing == null) {
        await api.createService(body);
      } else {
        await api.updateService(widget.existing!.id, body);
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
      title: Text(widget.existing == null ? "Nova usluga" : "Uredi uslugu"),
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
                DropdownButtonFormField<int>(
                  initialValue: _categoryId,
                  decoration: const InputDecoration(labelText: "Kategorija"),
                  items: widget.categories
                      .map((c) =>
                          DropdownMenuItem(value: c.id, child: Text(c.name)))
                      .toList(),
                  onChanged: (v) => setState(() => _categoryId = v),
                ),
                const SizedBox(height: 12),
                if (widget.salons.length > 1)
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
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _price,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: "Cijena (KM)"),
                        validator: (v) =>
                            (double.tryParse((v ?? "").replaceAll(",", ".")) == null)
                                ? "Broj"
                                : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: "Trajanje (min)"),
                        validator: (v) =>
                            (int.tryParse(v ?? "") == null) ? "Broj" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _desc,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: "Opis"),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Usluga je aktivna"),
                  value: _active,
                  onChanged: (v) => setState(() => _active = v),
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
