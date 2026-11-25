import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/widgets/verse_of_the_day_card.dart';

void main() {
  test('daily verse schedule has 366 distinct references', () {
    final references = List.generate(366, dailyVerseReference);

    expect(references.toSet(), hasLength(366));
    expect(references.first, 'Provérbios 1:1');
    expect(references[365], 'Provérbios 25:12');
  });

  test('daily verse references wrap after the full-year schedule', () {
    expect(dailyVerseReference(366), dailyVerseReference(0));
  });
}
