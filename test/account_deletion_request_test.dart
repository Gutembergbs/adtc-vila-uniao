import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/utils/account_deletion_request.dart';

void main() {
  test(
    'builds a deletion request email with the signed-in account details',
    () {
      final uri = buildAccountDeletionRequestUri(
        name: 'Pessoa Teste',
        email: 'pessoa@example.com',
        userId: 'user-123',
      );

      expect(uri.scheme, 'mailto');
      expect(uri.path, accountDeletionSupportEmail);
      expect(uri.queryParameters['subject'], contains('exclusão de conta'));
      expect(uri.queryParameters['body'], contains('Pessoa Teste'));
      expect(uri.queryParameters['body'], contains('pessoa@example.com'));
      expect(uri.queryParameters['body'], contains('user-123'));
      expect(uri.queryParameters['body'], isNot(contains('senha')));
    },
  );
}
