import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../services/api_service.dart";
import "../../widgets/common.dart";

enum _ReferenceKind {
  city("Gradovi", "Grad", 100),
  category("Kategorije", "Kategorija", 100),
  tag("Oznake recenzija", "Oznaka", 60);

  const _ReferenceKind(this.tab, this.label, this.maxLength);
  final String tab;
  final String label;
  final int maxLength;
}

typedef _ReferenceRow = ({int id, String name, String? detail});

class ReferenceScreen extends StatelessWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: _ReferenceKind.values.length,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader("Referentni podaci"),
            const SizedBox(height: 16),
            TabBar(tabs: [
              for (final kind in _ReferenceKind.values) Tab(text: kind.tab)
            ]),
            const SizedBox(height: 16),
            Expanded(
                child: TabBarView(
              children: [
                for (final kind in _ReferenceKind.values) _ReferenceList(kind)
              ],
            )),
          ],
        ),
      );
}

class _ReferenceList extends StatefulWidget {
  const _ReferenceList(this.kind);
  final _ReferenceKind kind;

  @override
  State<_ReferenceList> createState() => _ReferenceListState();
}

class _ReferenceListState extends State<_ReferenceList> {
  List<_ReferenceRow> _rows = [];
  int _page = 1;
  int _totalPages = 0;
  int _revision = 0;
  String _search = "";
  Object? _error;
  bool _loading = false;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _error = null;
    });
    final api = context.read<ApiService>();
    try {
      final (List<_ReferenceRow> rows, int pages) = switch (widget.kind) {
        _ReferenceKind.city => await api
            .getCities(page: _page, pageSize: 25, search: _search)
            .then((result) => (
                  result.items
                      .map((item) =>
                          (id: item.id, name: item.name, detail: item.region))
                      .toList(),
                  result.totalPages
                )),
        _ReferenceKind.category => await api
            .getCategories(page: _page, pageSize: 25, search: _search)
            .then((result) => (
                  result.items
                      .map((item) =>
                          (id: item.id, name: item.name, detail: item.iconName))
                      .toList(),
                  result.totalPages
                )),
        _ReferenceKind.tag =>
          await api.getTags(page: _page, search: _search).then((result) => (
                result.items
                    .map((item) => (id: item.id, name: item.name, detail: null))
                    .toList(),
                result.totalPages
              )),
      };
      if (!mounted || revision != _revision) return;
      if (_page > 1 && _page > pages) {
        _page = pages > 0 ? pages : 1;
        await _load();
        return;
      }
      _rows = rows;
      _totalPages = pages;
    } catch (error) {
      if (mounted && revision == _revision) _error = error;
    } finally {
      if (mounted && revision == _revision) setState(() => _loading = false);
    }
  }

  Future<void> _edit([_ReferenceRow? row]) async {
    setState(() => _mutating = true);
    final api = context.read<ApiService>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ReferenceForm(kind: widget.kind, row: row, api: api),
    );
    if (!mounted) return;
    setState(() => _mutating = false);
    if (saved == true) {
      showOk(context, "Podaci su spremljeni.");
      await _load();
    }
  }

  Future<void> _delete(_ReferenceRow row) async {
    setState(() => _mutating = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text("Potvrdi brisanje"),
          content: Text("Obrisati zapis „${row.name}”?"),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialog, false),
                child: const Text("Odustani")),
            FilledButton(
                onPressed: () => Navigator.pop(dialog, true),
                child: const Text("Obriši")),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final api = context.read<ApiService>();
      await switch (widget.kind) {
        _ReferenceKind.city => api.deleteCity(row.id),
        _ReferenceKind.category => api.deleteCategory(row.id),
        _ReferenceKind.tag => api.deleteTag(row.id),
      };
      if (!mounted) return;
      showOk(context, "Zapis je obrisan.");
      await _load();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(children: [
            Expanded(child: ListSearch(onSearch: (value) {
              _search = value;
              _page = 1;
              _load();
            })),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: _loading || _mutating ? null : () => _edit(),
              icon: const Icon(Icons.add),
              label: Text("Dodaj · ${widget.kind.label}"),
            ),
          ]),
          ListPages(
              page: _page,
              totalPages: _totalPages,
              loading: _loading || _mutating,
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
                      : _rows.isEmpty
                          ? const EmptyView("Nema rezultata")
                          : ListView.separated(
                              itemCount: _rows.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final row = _rows[index];
                                return ListTile(
                                  title: Text(row.name),
                                  subtitle: row.detail == null
                                      ? null
                                      : Text(row.detail!),
                                  trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                            tooltip: "Uredi",
                                            onPressed: _mutating
                                                ? null
                                                : () => _edit(row),
                                            icon: const Icon(
                                                Icons.edit_outlined)),
                                        IconButton(
                                            tooltip: "Obriši",
                                            onPressed: _mutating
                                                ? null
                                                : () => _delete(row),
                                            icon: const Icon(
                                                Icons.delete_outline)),
                                      ]),
                                );
                              },
                            )),
        ],
      );
}

class _ReferenceForm extends StatefulWidget {
  const _ReferenceForm(
      {required this.kind, required this.row, required this.api});
  final _ReferenceKind kind;
  final _ReferenceRow? row;
  final ApiService api;

  @override
  State<_ReferenceForm> createState() => _ReferenceFormState();
}

class _ReferenceFormState extends State<_ReferenceForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.row?.name);
  late final _detail = TextEditingController(text: widget.row?.detail);
  bool _saving = false;
  Object? _error;

  @override
  void dispose() {
    _name.dispose();
    _detail.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final id = widget.row?.id;
    final name = _name.text.trim();
    final detail = _detail.text.trim();
    try {
      switch (widget.kind) {
        case _ReferenceKind.city:
          final body = {"name": name, "region": detail};
          if (id == null) {
            await widget.api.createCity(body);
          } else {
            await widget.api.updateCity(id, body);
          }
        case _ReferenceKind.category:
          final body = {
            "name": name,
            "iconName": detail.isEmpty ? null : detail
          };
          if (id == null) {
            await widget.api.createCategory(body);
          } else {
            await widget.api.updateCategory(id, body);
          }
        case _ReferenceKind.tag:
          await widget.api.saveTag(id, name);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(
            "${widget.row == null ? "Dodaj" : "Uredi"} · ${widget.kind.label}"),
        content: SizedBox(
            width: 360,
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  maxLength: widget.kind.maxLength,
                  decoration: const InputDecoration(labelText: "Naziv"),
                  validator: (value) =>
                      (value?.trim().isEmpty ?? true) ? "Unesite naziv." : null,
                ),
                if (widget.kind != _ReferenceKind.tag)
                  TextFormField(
                    controller: _detail,
                    enabled: !_saving,
                    maxLength: widget.kind == _ReferenceKind.city ? 100 : 50,
                    decoration: InputDecoration(
                        labelText: widget.kind == _ReferenceKind.city
                            ? "Regija / kanton"
                            : "Ikona (opcionalno)"),
                    validator: (value) => widget.kind == _ReferenceKind.city &&
                            (value?.trim().isEmpty ?? true)
                        ? "Unesite regiju."
                        : null,
                  ),
                if (_error != null)
                  Text("$_error",
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ])),
            )),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context),
              child: const Text("Odustani")),
          FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? "Spremanje…" : "Sačuvaj")),
        ],
      );
}
