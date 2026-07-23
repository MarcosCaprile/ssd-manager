import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ssd_manager/core/api/api_client.dart';
import 'package:ssd_manager/core/security/session_storage.dart';

void main() {
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
