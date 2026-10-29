import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../../providers/auth_provider.dart";
import "../../theme/app_theme.dart";
import "../../widgets/common.dart";

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _username = TextEditingController(text: "admin");
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
      body: Row(
        children: [
          // Lijeva brend strana
          Expanded(
            child: Container(
              color: AppColors.sidebar,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.content_cut,
                        size: 72, color: Colors.white),
                    const SizedBox(height: 16),
                    const Text("RezervisiMe",
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    const SizedBox(height: 8),
                    Text("Administrativni panel",
                        style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
            ),
          ),
          // Desna forma
          Expanded(
            child: Center(
              child: SizedBox(
                width: 360,
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text("Prijava",
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      const Text("Prijavi se kao administrator ili frizer",
                          style: TextStyle(color: AppColors.textSecondary)),
                      const SizedBox(height: 28),
                      TextFormField(
                        controller: _username,
                        decoration: const InputDecoration(
                            labelText: "Korisnicko ime",
                            prefixIcon: Icon(Icons.person_outline)),
                        validator: (v) => (v == null || v.isEmpty)
                            ? "Unesite korisnicko ime"
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        onFieldSubmitted: (_) => _submit(),
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
                      const SizedBox(height: 16),
                      const Text(
                          "admin / Test1234!  ·  desktop / Test1234!",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
