import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "services/api_client.dart";
import "services/api_service.dart";
import "providers/auth_provider.dart";
import "theme/app_theme.dart";
import "screens/auth/login_screen.dart";
import "screens/shell.dart";
import "widgets/common.dart";

void main() {
  final apiClient = ApiClient();
  final apiService = ApiService(apiClient);
  runApp(RezervisiMeDesktop(apiService: apiService));
}

class RezervisiMeDesktop extends StatelessWidget {
  final ApiService apiService;
  const RezervisiMeDesktop({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
      ],
      child: MaterialApp(
        title: "RezervisiMe Admin",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _Gate(),
      ),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await context.read<AuthProvider>().tryAutoLogin();
    if (mounted) setState(() => _checked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const Scaffold(body: LoadingView());
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const AppShell() : const LoginScreen();
  }
}
