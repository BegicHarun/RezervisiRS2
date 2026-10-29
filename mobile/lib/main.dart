import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "services/api_client.dart";
import "services/api_service.dart";
import "providers/auth_provider.dart";
import "providers/notifications_provider.dart";
import "theme/app_theme.dart";
import "screens/auth/login_screen.dart";
import "screens/root_scaffold.dart";
import "widgets/common.dart";

void main() {
  final apiClient = ApiClient();
  final apiService = ApiService(apiClient);

  runApp(RezervisiMeApp(apiService: apiService));
}

class RezervisiMeApp extends StatelessWidget {
  final ApiService apiService;
  const RezervisiMeApp({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider(create: (_) => AuthProvider(apiService)),
        ChangeNotifierProvider(create: (_) => NotificationsProvider(apiService)),
      ],
      child: MaterialApp(
        title: "RezervisiMe",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const _AuthGate(),
      ),
    );
  }
}

/// Odlucuje da li prikazati login ili glavni ekran.
class _AuthGate extends StatefulWidget {
  const _AuthGate();
  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
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
    if (!_checked) {
      return const Scaffold(body: LoadingView());
    }
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn ? const RootScaffold() : const LoginScreen();
  }
}
