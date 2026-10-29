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
              child: CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  user == null || user.firstName.isEmpty
                      ? "?"
                      : user.firstName[0].toUpperCase(),
                  style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary),
                ),
              ),
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<AuthProvider>().user;
    _first = TextEditingController(text: u?.firstName ?? "");
    _last = TextEditingController(text: u?.lastName ?? "");
    _loadCities();
  }

  Future<void> _loadCities() async {
    try {
      final res = await context.read<ApiService>().getCities();
      if (!mounted) return;
      setState(() {
        _cities = res.items;
        // Predizaberi trenutni grad korisnika po imenu, ako se poklopi.
        final cityName = context.read<AuthProvider>().user?.cityName;
        final match = _cities.where((c) => c.name == cityName);
        if (match.isNotEmpty) _cityId = match.first.id;
      });
    } catch (_) {
      // dropdown ostaje prazan - grad je opcionalan
    }
  }

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ApiService>().updateProfile({
        "firstName": _first.text.trim(),
        "lastName": _last.text.trim(),
        "cityId": _cityId,
      });
      await context.read<AuthProvider>().refreshUser();
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
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Izmjena profila",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
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
            DropdownButtonFormField<int>(
              initialValue: _cityId,
              decoration: const InputDecoration(labelText: "Grad"),
              items: _cities
                  .map((c) =>
                      DropdownMenuItem(value: c.id, child: Text(c.name)))
                  .toList(),
              onChanged: (v) => setState(() => _cityId = v),
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
                  : const Text("Sacuvaj"),
            ),
          ],
        ),
      ),
    );
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
      await context
          .read<ApiService>()
          .changePassword(_current.text, _new.text);
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
