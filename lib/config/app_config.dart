class AppConfig {
  AppConfig._();

  static const apiBaseUrl = String.fromEnvironment(
    'SSD_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8080/api/v1',
  );

  static const appName = 'SSD Manager';
  static const schoolTimezone = 'Europe/Berlin';
  static const maxAnnouncementLength = 2000;
}
