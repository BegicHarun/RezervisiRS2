import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../models/salon.dart";
import "../../services/api_service.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "../home/home_screen.dart";

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _search = TextEditingController();
  List<CityDto> _cities = [];
  int? _cityId;
  bool _loading = false;
  List<SalonDto> _results = [];
  int _total = 0;
  int _page = 1;
  int _pages = 0;
  int _request = 0;
  int _requestedPage = 1;
  String _submitted = "";
  Object? _error;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _doSearch();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      final res = await context.read<ApiService>().getCities();
      if (mounted) setState(() => _cities = res.items);
    } catch (error) {
      if (mounted) showError(context, error);
    }
  }

  Future<void> _doSearch() {
    _submitted = _search.text.trim();
    return _loadPage(1);
  }

  Future<void> _loadPage(int page) async {
    final request = ++_request;
    _requestedPage = page;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await context.read<ApiService>().getSalons(
            search: _submitted.isEmpty ? null : _submitted,
            page: page,
            cityId: _cityId,
            pageSize: 50,
          );
      if (!mounted || request != _request) return;
      setState(() {
        _page = res.page;
        _pages = res.totalPages;
        _results = res.items;
        _total = res.totalCount;
      });
    } catch (e) {
      if (mounted && request == _request) setState(() => _error = e);
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pretraga salona")),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _doSearch(),
                    decoration: InputDecoration(
                      hintText: "Naziv ili adresa...",
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _doSearch),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int?>(
                          initialValue: _cityId,
                          decoration: const InputDecoration(labelText: "Grad"),
                          items: [
                            const DropdownMenuItem(
                                value: null, child: Text("Svi gradovi")),
                            ..._cities.map((c) => DropdownMenuItem(
                                value: c.id, child: Text(c.name))),
                          ],
                          onChanged: (v) {
                            setState(() => _cityId = v);
                            _doSearch();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_loading)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text("$_total rezultata",
                      style: const TextStyle(color: AppColors.textSecondary)),
                ),
              ),
            Expanded(
              child: _loading
                  ? const LoadingView()
                  : _error != null
                      ? Center(
                          child: TextButton(
                              onPressed: () => _loadPage(_requestedPage),
                              child: Text("PokuÅ¡aj ponovo: $_error")))
                      : _results.isEmpty
                          ? const EmptyView("Nema rezultata",
                              icon: Icons.search_off)
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, i) =>
                                  SalonCard(salon: _results[i]),
                            ),
            ),
            if (_pages > 1 && _error == null)
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                IconButton(
                  tooltip: "Prethodna stranica",
                  onPressed: _loading || _page <= 1
                      ? null
                      : () => _loadPage(_page - 1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Text("$_page / $_pages"),
                IconButton(
                  tooltip: "SljedeÄ‡a stranica",
                  onPressed: _loading || _page >= _pages
                      ? null
                      : () => _loadPage(_page + 1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}
