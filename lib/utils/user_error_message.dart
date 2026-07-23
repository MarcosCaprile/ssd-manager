import '../core/api/api_exception.dart';

const _connectionMessage =
    'Die Verbindung zum Server konnte nicht hergestellt werden. '
    'Prüfe deine Internetverbindung und versuche es erneut.';
const _genericMessage =
    'Das hat leider nicht funktioniert. Bitte versuche es erneut.';

String userErrorMessage(Object? error, {String fallback = _genericMessage}) {
  if (error is ApiException) {
    final message = error.message.trim();
    if (_isSafeServerMessage(message)) return message;
    return switch (error.statusCode) {
      401 => 'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.',
      403 => 'Du hast für diese Aktion keine Berechtigung.',
      404 => 'Der gewünschte Eintrag wurde nicht gefunden.',
      409 =>
        'Die Änderung konnte wegen eines Konflikts nicht gespeichert werden.',
      413 => 'Die ausgewählte Datei ist zu groß oder dein Speicher ist voll.',
      429 => 'Zu viele Versuche. Bitte warte kurz und versuche es erneut.',
      final code when code != null && code >= 500 =>
        'Der Dienst ist gerade nicht verfügbar. Bitte versuche es später erneut.',
      _ => fallback,
    };
  }

  final text = error?.toString().toLowerCase() ?? '';
  if (text.contains('socket') ||
      text.contains('timeout') ||
      text.contains('connection') ||
      text.contains('network') ||
      text.contains('host lookup') ||
      text.contains('clientexception')) {
    return _connectionMessage;
  }
  return fallback;
}

bool _isSafeServerMessage(String value) {
  if (value.isEmpty || value.length > 300) return false;
  final lower = value.toLowerCase();
  const unsafe = [
    'http://',
    'https://',
    '/api/',
    'exception',
    'stack trace',
    'sqlstate',
    'pdo',
    'uri=',
    '<html',
    '{',
    '}',
  ];
  return !unsafe.any(lower.contains);
}
