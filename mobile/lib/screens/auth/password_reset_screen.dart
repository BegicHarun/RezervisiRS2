import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../services/api_service.dart";
import "../../widgets/common.dart";

class PasswordResetScreen extends StatefulWidget {
  const PasswordResetScreen({super.key});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _token = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _requested = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _token.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final api = context.read<ApiService>();
    try {
      if (_requested) {
        await api.resetPassword(
            _email.text.trim(), _token.text.trim(), _password.text);
        if (!mounted) return;
        showOk(
            context, "Lozinka je promijenjena. Prijavite se novom lozinkom.");
        Navigator.pop(context);
      } else {
        await api.requestPasswordReset(_email.text.trim());
        if (mounted) setState(() => _requested = true);
      }
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text("Reset lozinke")),
        body: SafeArea(
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                TextFormField(
                  controller: _email,
                  enabled: !_requested && !_busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "E-mail"),
                  validator: (value) => RegExp(r"^[^\s@]+@[^\s@]+\.[^\s@]+$")
                          .hasMatch(value?.trim() ?? "")
                      ? null
                      : "Unesite ispravnu e-mail adresu.",
                ),
                if (_requested) ...[
                  const SizedBox(height: 16),
                  const Text(
                      "Ako postoji aktivan nalog za ovu adresu, kod će stići e-mailom. Vrijedi 30 minuta."),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _token,
                    decoration:
                        const InputDecoration(labelText: "Kod iz e-maila"),
                    validator: (value) => (value?.trim().isEmpty ?? true)
                        ? "Zalijepite kod iz e-maila."
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: "Nova lozinka"),
                    validator: (value) {
                      final length = value?.length ?? 0;
                      return length < 6 || length > 100
                          ? "Unesite od 6 do 100 znakova."
                          : null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmation,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: "Ponovite novu lozinku"),
                    validator: (value) => value == _password.text
                        ? null
                        : "Lozinke se ne podudaraju.",
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: Text(_requested ? "Promijeni lozinku" : "Pošalji kod"),
                ),
                if (_requested)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _token.clear();
                              _password.clear();
                              _confirmation.clear();
                              _requested = false;
                            }),
                    child: const Text("Zatraži novi kod"),
                  ),
              ],
            ),
          ),
        ),
      );
}
