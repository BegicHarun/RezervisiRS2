import "dart:convert";
import "package:image_picker/image_picker.dart";
import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../providers/auth_provider.dart";
import "../../providers/notifications_provider.dart";
import "../../services/api_service.dart";
import "../../models/salon.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(title: const Text("Profil")),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 16),
            Center(
              child: _ProfileAvatar(
                  imageUrl: user?.imageUrl, name: user?.firstName ?? ""),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(user?.fullName ?? "",
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            ),
            Center(
              child: Text("@${user?.username ?? ''}",
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 24),
            _InfoTile(
                icon: Icons.email_outlined,
                label: "Email",
                value: user?.email ?? "-"),
            if (user?.cityName != null)
              _InfoTile(
                  icon: Icons.location_city_outlined,
                  label: "Grad",
                  value: user!.cityName!),
            _InfoTile(
                icon: Icons.badge_outlined,
                label: "Uloga",
                value: user?.roles.join(", ") ?? "-"),
            const SizedBox(height: 24),
            // Izmjena profila (uputa 2.3)
            ElevatedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _EditProfileSheet(),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: const Text("Izmijeni profil"),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            // Promjena lozinke (uputa 2.3 + 4)
            OutlinedButton.icon(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const _ChangePasswordSheet(),
              ),
              icon: const Icon(Icons.lock_outline),
              label: const Text("Promijeni lozinku"),
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                context.read<NotificationsProvider>().stopPolling();
                context.read<AuthProvider>().logout();
              },
              icon: const Icon(Icons.logout, color: AppColors.cancelled),
              label: const Text("Odjava",
                  style: TextStyle(color: AppColors.cancelled)),
              style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.cancelled),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Forma za izmjenu profila (ime, prezime, grad). Salje PUT /profile.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet();
  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _first;
  late TextEditingController _last;
  List<CityDto> _cities = [];
  int? _cityId;
  String? _imageUrl;
  String? _cityName;
  bool _citiesReady = false;
  bool _cityLoadFailed = false;
  bool _picking = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user;
    _imageUrl = u?.imageUrl;
    _cityName = u?.cityName;
    _first = TextEditingController(text: u?.firstName ?? "");
    _last = TextEditingController(text: u?.lastName ?? "");
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final api = context.read<ApiService>();
      final cities = <CityDto>[];
      var page = 1;
      while (mounted) {
        final result = await api.getCities(page: page);
        cities.addAll(result.items);
        if (page >= result.totalPages) break;
        page++;
      }
      if (!mounted) return;
      setState(() {
        _cities = cities;
        final matches = cities.where((city) => city.name == _cityName).toList();
        if (matches.length == 1) _cityId = matches.single.id;
        _citiesReady = true;
        _cityLoadFailed = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cityLoadFailed = true);
    }
  }

  Future<void> _pickImage() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (file == null || !mounted) return;
      if (await file.length() > 512 * 1024) {
        throw const FormatException("Odaberite sliku do 512 KB.");
      }
      final bytes = await file.readAsBytes();
      final jpeg = bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final png = bytes.length > 8 &&
          const [137, 80, 78, 71, 13, 10, 26, 10]
              .asMap()
              .entries
              .every((entry) => bytes[entry.key] == entry.value);
      if (!jpeg && !png) {
        throw const FormatException("Odaberite JPEG ili PNG sliku.");
      }
      final type = jpeg ? "jpeg" : "png";
      if (mounted) {
        setState(
            () => _imageUrl = "data:image/$type;base64,${base64Encode(bytes)}");
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || _picking || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final auth = context.read<AuthProvider>();
      await context.read<ApiService>().updateProfile({
        "firstName": _first.text.trim(),
        "lastName": _last.text.trim(),
        "cityId": _cityId,
        "imageUrl": _imageUrl,
      });
      if (!mounted) return;
      await auth.refreshUser();
      if (mounted) {
        Navigator.pop(context);
        showOk(context, "Profil je uspjesno azuriran.");
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
      child: SingleChildScrollView(
          child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Izmjena profila",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Center(
                child: _ProfileAvatar(imageUrl: _imageUrl, name: _first.text)),
            Wrap(alignment: WrapAlignment.center, children: [
              TextButton(
                  onPressed: _busy || _picking ? null : _pickImage,
                  child: const Text("Odaberi sliku")),
              if (_imageUrl != null)
                TextButton(
                    onPressed: _busy || _picking
                        ? null
                        : () => setState(() => _imageUrl = null),
                    child: const Text("Ukloni sliku")),
            ]),
            TextFormField(
              controller: _first,
              decoration: const InputDecoration(labelText: "Ime"),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Ime je obavezno." : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _last,
              decoration: const InputDecoration(labelText: "Prezime"),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? "Prezime je obavezno."
                  : null,
            ),
            const SizedBox(height: 12),
            if (_cityLoadFailed)
              TextButton(
                  onPressed: _loadCities,
                  child:
                      const Text("Gradovi se nisu učitali. Pokušaj ponovo.")),
            DropdownButtonFormField<int>(
              key: ValueKey(_citiesReady),
              initialValue: _cityId,
              validator: (value) => _cityName != null && value == null
                  ? "Odaberite postojeći grad."
                  : null,
              decoration: const InputDecoration(labelText: "Grad"),
              items: _cities
                  .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: !_citiesReady || _busy
                  ? null
                  : (v) => setState(() => _cityId = v),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed:
                  _busy || _picking || (!_citiesReady && _cityName != null)
                      ? null
                      : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Sacuvaj"),
            ),
          ],
        ),
      )),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.imageUrl, required this.name});

  final String? imageUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
        child: Text(name.isEmpty ? "?" : name[0].toUpperCase(),
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)));
    final url = imageUrl;
    Widget image = fallback;
    if (url != null && url.isNotEmpty) {
      try {
        final uri = Uri.parse(url);
        if (uri.scheme == "data") {
          image = Image.memory(uri.data!.contentAsBytes(),
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
        } else if (uri.scheme == "https" || uri.scheme == "http") {
          image = Image.network(url,
              fit: BoxFit.cover, errorBuilder: (_, __, ___) => fallback);
        }
      } on FormatException {
        image = fallback;
      }
    }
    return ClipOval(
        child: Container(
      color: AppColors.primary.withValues(alpha: 0.15),
      width: 88,
      height: 88,
      child: image,
    ));
  }
}

/// Forma za promjenu lozinke. Trazi staru lozinku (uputa 4). Salje POST /profile/change-password.
class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiService>().changePassword(_current.text, _new.text);
      if (mounted) {
        Navigator.pop(context);
        showOk(context, "Lozinka je uspjesno promijenjena.");
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 20, 16, bottom + 20),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Promjena lozinke",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Trenutna lozinka"),
              validator: (v) => (v == null || v.isEmpty)
                  ? "Trenutna lozinka je obavezna."
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: "Nova lozinka"),
              validator: (v) => (v == null || v.length < 6)
                  ? "Nova lozinka mora imati najmanje 6 karaktera."
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: "Potvrdi novu lozinku"),
              validator: (v) =>
                  (v != _new.text) ? "Lozinke se ne podudaraju." : null,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _busy ? null : _save,
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Promijeni lozinku"),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoTile(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.right,
                style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
