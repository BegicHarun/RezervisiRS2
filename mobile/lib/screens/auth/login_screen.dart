import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../providers/auth_provider.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";
import "register_screen.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController(text: "mobile");
  final _password = TextEditingController(text: "Test1234!");
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await context
          .read<AuthProvider>()
          .login(_username.text.trim(), _password.text);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loading = context.watch<AuthProvider>().loading;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.content_cut,
                      size: 64, color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text("RezervisiMe",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                  const Text("Rezervisi svoj termin u par klikova",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _username,
                    decoration: const InputDecoration(
                        labelText: "Korisnicko ime",
                        prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Unesite korisnicko ime" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                        labelText: "Lozinka",
                        prefixIcon: Icon(Icons.lock_outline)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? "Unesite lozinku" : null,
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
                        : const Text("Prijava"),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen())),
                    child: const Text("Nemas nalog? Registruj se"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
