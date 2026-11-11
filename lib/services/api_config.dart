/// Configuração de acesso à API Django do RotaSaúde.
///
/// A URL base é definida na compilação, sem credenciais embutidas:
/// `flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000`.
abstract final class ApiConfig {
  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const requestTimeout = Duration(seconds: 10);

  static Uri get baseUri => Uri.parse(baseUrl);
}
