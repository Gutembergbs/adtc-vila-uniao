import 'package:adtc_vila_uniao/models/member_notice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads sent and viewed timestamps from a member notice row', () {
    final notice = MemberNotice.fromDatabase({
      'id': 'notice-1',
      'membro_id': 'member-1',
      'departamento_id': 'jovens',
      'titulo': 'Ensaio',
      'resumo': 'Aviso do ensaio',
      'conteudo': 'O ensaio será às 18h.',
      'categoria': 'Pessoal',
      'criado_em': '2026-10-27T09:00:00.000Z',
      'visualizado_em': '2026-10-27T10:15:00.000Z',
    });

    expect(notice.createdAt, DateTime.utc(2026, 10, 27, 9));
    expect(notice.viewedAt, DateTime.utc(2026, 10, 27, 10, 15));
  });

  test('leaves viewed timestamp empty until the member opens a notice', () {
    final notice = MemberNotice.fromDatabase({
      'id': 'notice-2',
      'membro_id': 'member-1',
      'departamento_id': 'jovens',
      'titulo': 'Ensaio',
      'resumo': '',
      'conteudo': 'O ensaio será às 18h.',
      'categoria': 'Pessoal',
      'criado_em': '2026-10-27T09:00:00.000Z',
      'visualizado_em': null,
    });

    expect(notice.viewedAt, isNull);
  });
}
