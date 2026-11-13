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
  Object? _startupError;
  late final AuthProvider _auth;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthProvider>()..addListener(_onSessionChanged);
    _init();
  }

  Future<void> _init() async {
    try {
      await _auth.tryAutoLogin();
      if (mounted) setState(() => _checked = true);
    } catch (error) {
      if (mounted) setState(() => _startupError = error);
    }
  }

  void _onSessionChanged() {
    if (!_auth.sessionExpired || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _auth.sessionExpired) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _auth.removeListener(_onSessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_startupError != null) {
      return Scaffold(
          body: Center(
              child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text("Povezivanje s API-jem nije uspjelo."),
          TextButton(
              onPressed: () {
                setState(() => _startupError = null);
                _init();
              },
              child: const Text("Pokušaj ponovo")),
        ],
      )));
    }
    if (!_checked) {
      return const Scaffold(body: LoadingView());
    }
    final auth = context.watch<AuthProvider>();
    return auth.isLoggedIn
        ? ChangeNotifierProvider(
            create: (_) => NotificationsProvider(context.read<ApiService>()),
            child: const RootScaffold(),
          )
        : const LoginScreen();
  }
}
