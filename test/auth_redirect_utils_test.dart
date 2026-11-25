import 'package:adtc_vila_uniao/utils/auth_redirect_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recognizes signup confirmation in query parameters', () {
    expect(
      isEmailConfirmationCallback(
        Uri.parse('https://igreja-flutter.web.app/?type=signup'),
      ),
      isTrue,
    );
  });

  test('recognizes signup confirmation in the URL fragment', () {
    expect(
      isEmailConfirmationCallback(
        Uri.parse(
          'https://igreja-flutter.web.app/#access_token=token&type=signup',
        ),
      ),
      isTrue,
    );
  });

  test('does not treat password recovery as email confirmation', () {
    expect(
      isEmailConfirmationCallback(
        Uri.parse('https://igreja-flutter.web.app/?type=recovery'),
      ),
      isFalse,
    );
  });

  test('does not treat a regular site visit as email confirmation', () {
    expect(
      isEmailConfirmationCallback(Uri.parse('https://igreja-flutter.web.app/')),
      isFalse,
    );
  });
}
