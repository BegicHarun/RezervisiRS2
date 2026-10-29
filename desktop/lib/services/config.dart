/// Konfiguracija desktop aplikacije.
///
/// API adresa se cita iz --dart-define (uputa 3.3):
///   flutter run -d windows --dart-define=API_BASE_URL=http://localhost:5126/api
/// Ako --dart-define nije zadan, koristi se default za lokalni razvoj
/// (desktop vidi backend direktno na localhost; backend u Dockeru slusa na 5126).
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:5126/api',
  );
}
