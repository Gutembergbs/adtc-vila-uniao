import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/utils/calendar_date_utils.dart';

void main() {
  test('month calendar starts on Sunday and ends on Saturday', () {
    final dates = monthCalendarDates(DateTime(2026, 11));

    expect(dates, hasLength(42));
    expect(dates[0], DateTime(2026, 11, 1));
    expect(dates[6], DateTime(2026, 11, 7));
    expect(dates[7], DateTime(2026, 11, 8));
  });

  test('month calendar leaves leading cells before a Monday first', () {
    final dates = monthCalendarDates(DateTime(2026, 6));

    expect(dates[0], isNull);
    expect(dates[1], DateTime(2026, 6, 1));
    expect(dates[7], DateTime(2026, 6, 7));
  });

  test('Brazilian Portuguese date picker starts weeks on Sunday', () async {
    final localizations = await GlobalMaterialLocalizations.delegate.load(
      const Locale('pt', 'BR'),
    );

    expect(localizations.firstDayOfWeekIndex, 0);
  });
}
