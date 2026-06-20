class AppConfig {
  const AppConfig._();

  static const appEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'production',
  );

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.gymtelligent.io.vn/api/v1',
  );
}
