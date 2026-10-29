/// Konfiguracija aplikacije.
///
/// API adresa se cita iz --dart-define (uputa 3.3):
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5126/api
/// Ako --dart-define nije zadan, koristi se default za lokalni razvoj
/// (Android emulator vidi host preko 10.0.2.2; backend u Dockeru slusa na 5126).
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5126/api',
  );
}
