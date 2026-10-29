import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/core.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ReferenceScreen extends StatefulWidget {
  const ReferenceScreen({super.key});
  @override
  State<ReferenceScreen> createState() => _ReferenceScreenState();
}

class _ReferenceScreenState extends State<ReferenceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<CityDto> _cities = [];
  List<ServiceCategoryDto> _categories = [];
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
      _cities = (await api.getCities()).items;
      _categories = (await api.getCategories()).items;
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader("Referentni podaci",
            subtitle: "Gradovi i kategorije usluga",
            action: ElevatedButton.icon(
              onPressed: () =>
                  _tab.index == 0 ? _editCity() : _editCategory(),
              icon: const Icon(Icons.add),
              label: Text(_tab.index == 0 ? "Novi grad" : "Nova kategorija"),
            )),
        const SizedBox(height: 16),
        TabBar(
          controller: _tab,
          labelColor: AppColors.primary,
          indicatorColor: AppColors.primary,
          onTap: (_) => setState(() {}),
          tabs: const [Tab(text: "Gradovi"), Tab(text: "Kategorije")],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _loading
              ? const LoadingView()
              : TabBarView(
                  controller: _tab,
                  children: [_citiesTab(), _categoriesTab()],
                ),
        ),
      ],
    );
  }

  Widget _citiesTab() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: _cities.isEmpty
          ? const EmptyView("Nema gradova")
          : SingleChildScrollView(
              child: SizedBox(
                width: double.infinity,
                child: DataTable(
                  headingRowColor:
                      WidgetStateProperty.all(AppColors.background),
                  columns: const [
                    DataColumn(label: Text("Naziv")),
                    DataColumn(label: Text("Regija / kanton")),
                    DataColumn(label: Text("Saloni")),
                    DataColumn(label: Text("Akcije")),
                  ],
                  rows: _cities
                      .map((c) => DataRow(cells: [
                            DataCell(Text(c.name)),
                            DataCell(Text(c.region)),
                            DataCell(Text("${c.salonCount}")),
                            DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                              IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                  onPressed: () => _editCity(existing: c)),
                              IconButton(
                                  icon: const Icon(Icons.delete_outline,
                                      size: 20, color: AppColors.cancelled),
                                  onPressed: () => _deleteCity(c)),
                            ])),
                          ]))
                      .toList(),
                ),
              ),
            ),
    );
  }

  Widget _categoriesTab() {
    return Container(
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border)),
      child: _categories.isEmpty
          ? const EmptyView("Nema kategorija")
          : ListView.separated(
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final c = _categories[i];
                return ListTile(
                  title: Text(c.name),
                  subtitle: c.iconName != null ? Text("Ikona: ${c.iconName}") : null,
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => _editCategory(existing: c)),
                    IconButton(
                        icon: const Icon(Icons.delete_outline,
                            size: 20, color: AppColors.cancelled),
                        onPressed: () => _deleteCategory(c)),
                  ]),
                );
              },
            ),
    );
  }

  Future<void> _editCity({CityDto? existing}) async {
    final name = TextEditingController(text: existing?.name ?? "");
    final region = TextEditingController(text: existing?.region ?? "");
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? "Novi grad" : "Uredi grad"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Naziv")),
          const SizedBox(height: 12),
          TextField(
              controller: region,
              decoration: const InputDecoration(labelText: "Regija / kanton")),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Odustani")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Sacuvaj")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final body = {"name": name.text.trim(), "region": region.text.trim()};
      final api = context.read<ApiService>();
      if (existing == null) {
        await api.createCity(body);
      } else {
        await api.updateCity(existing.id, body);
      }
      if (mounted) showOk(context, "Sacuvano.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteCity(CityDto c) async {
    try {
      await context.read<ApiService>().deleteCity(c.id);
      if (mounted) showOk(context, "Grad obrisan.");
      _load();
    } catch (e) {
      // Backend vraca jasnu poruku ako je grad u upotrebi.
      if (mounted) showError(context, e);
    }
  }

  Future<void> _editCategory({ServiceCategoryDto? existing}) async {
    final name = TextEditingController(text: existing?.name ?? "");
    final icon = TextEditingController(text: existing?.iconName ?? "");
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null ? "Nova kategorija" : "Uredi kategoriju"),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: name,
              decoration: const InputDecoration(labelText: "Naziv")),
          const SizedBox(height: 12),
          TextField(
              controller: icon,
              decoration: const InputDecoration(
                  labelText: "Ikona (opcionalno)",
                  hintText: "npr. content_cut")),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Odustani")),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Sacuvaj")),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final body = {
        "name": name.text.trim(),
        "iconName": icon.text.trim().isEmpty ? null : icon.text.trim()
      };
      final api = context.read<ApiService>();
      if (existing == null) {
        await api.createCategory(body);
      } else {
        await api.updateCategory(existing.id, body);
      }
      if (mounted) showOk(context, "Sacuvano.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _deleteCategory(ServiceCategoryDto c) async {
    try {
      await context.read<ApiService>().deleteCategory(c.id);
      if (mounted) showOk(context, "Kategorija obrisana.");
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }
}
