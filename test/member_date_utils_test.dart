import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/utils/member_date_utils.dart';

void main() {
  test('formats ISO member dates as Brazilian dates', () {
    expect(formatMemberDate('2001-09-07'), '07/09/2001');
  });

  test('preserves member dates already formatted in Brazilian format', () {
    expect(formatMemberDate('07/09/2001'), '07/09/2001');
  });

  test('uses the fallback when the member date is empty', () {
    expect(formatMemberDate(null), 'Não informado');
    expect(formatMemberDate('  '), 'Não informado');
  });

  test('preserves unrecognized date values rather than hiding them', () {
    expect(formatMemberDate('Após o culto'), 'Após o culto');
  });
}
