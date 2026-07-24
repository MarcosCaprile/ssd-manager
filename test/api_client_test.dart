import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssd_manager/core/api/api_client.dart';
import 'package:ssd_manager/core/security/session_storage.dart';

void main() {
  test('GET requests explicitly bypass stale intermediary caches', () async {
    late http.Request captured;
    final client = ApiClient(
      sessionStorage: _EmptySessionStorage(),
      httpClient: MockClient((request) async {
        captured = request;
        return http.Response(
          '{"data":[],"message":null}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://example.test/api/v1',
    );

    await client.get('announcements');

    expect(captured.headers['Cache-Control'], 'no-cache, no-store');
    expect(captured.headers['Pragma'], 'no-cache');
  });

  test(
    'successful mutation stays successful when refresh signal throws',
    () async {
      var callbackCount = 0;
      final client = ApiClient(
        sessionStorage: _EmptySessionStorage(),
        httpClient: MockClient(
          (_) async => http.Response(
            '{"data":{"ok":true},"message":null}',
            200,
            headers: {'content-type': 'application/json'},
          ),
        ),
        baseUrl: 'https://example.test/api/v1',
        onMutationSucceeded: (method, path) {
          callbackCount++;
          expect(method, 'PATCH');
          expect(path, 'users/17/role');
          throw StateError('simulated local listener failure');
        },
      );

      final result =
          await client.patch('users/17/role', body: {'role': 'sani_leitung'})
              as Map<String, dynamic>;

      expect(result['ok'], isTrue);
      expect(callbackCount, 1);
    },
  );
}

class _EmptySessionStorage extends SessionStorage {
  @override
  Future<String?> accessToken() async => null;
}
