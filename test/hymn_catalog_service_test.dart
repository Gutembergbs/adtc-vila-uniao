import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/services/hymn_catalog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads all 640 Harpa Cristã titles and numbers only', () async {
    final hymns = await HymnCatalogService.load();

    expect(hymns, hasLength(640));
    expect(hymns.first.number, 1);
    expect(hymns.first.title, 'Chuvas De Graça');
    expect(hymns.last.number, 640);
    expect(hymns.every((hymn) => hymn.title.isNotEmpty), isTrue);
  });
}
