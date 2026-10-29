import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../providers/auth_provider.dart";
import "../../widgets/common.dart";

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context.read<AuthProvider>().register({
        "username": _username.text.trim(),
        "email": _email.text.trim(),
        "password": _password.text,
        "firstName": _firstName.text.trim(),
        "lastName": _lastName.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    return Scaffold(
      appBar: AppBar(title: const Text("Registracija")),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: "Ime"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Obavezno polje" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: "Prezime"),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Obavezno polje" : null,
                ),
                const SizedBox(height: 12),
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
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "Email"),
                  validator: (v) => (v == null || !v.contains("@"))
                      ? "Unesite ispravan email"
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Lozinka"),
                  validator: (v) => (v == null || v.length < 6)
                      ? "Najmanje 6 karaktera"
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: loading ? null : _submit,
                  child: loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text("Kreiraj nalog"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
