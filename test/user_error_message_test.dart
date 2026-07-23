import 'package:flutter_test/flutter_test.dart';
import 'package:ssd_manager/core/api/api_exception.dart';
import 'package:ssd_manager/utils/user_error_message.dart';

void main() {
  test('keeps understandable server messages', () {
    expect(
      userErrorMessage(
        const ApiException(
          'E-Mail/Benutzername oder Passwort ist nicht korrekt.',
          statusCode: 401,
        ),
      ),
      'E-Mail/Benutzername oder Passwort ist nicht korrekt.',
    );
  });

  test('hides technical server details', () {
    final message = userErrorMessage(
      const ApiException(
        'SQLSTATE[HY000] at https://example.test/api/v1/users',
        statusCode: 500,
      ),
    );

    expect(message, isNot(contains('SQLSTATE')));
    expect(message, isNot(contains('api/v1')));
    expect(message, contains('nicht verfügbar'));
  });

  test('maps raw network failures to a connection message', () {
    final message = userErrorMessage(Exception('SocketException: failed host'));

    expect(message, contains('Internetverbindung'));
    expect(message, isNot(contains('SocketException')));
  });
}
