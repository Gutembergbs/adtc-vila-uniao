import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/services/church_share_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a shareable image with the church logo', () async {
    final image = await ChurchShareService.createImage(
      title: 'Versículo do Dia',
      text: 'O Senhor é o meu pastor.\\nSalmos 23:1',
    );

    expect(image, isNotEmpty);
    expect(image.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
  });
}
