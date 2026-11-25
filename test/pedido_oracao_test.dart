import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/models/pedido_oracao.dart';
import 'package:adtc_vila_uniao/utils/validacao_pedido_oracao.dart';

void main() {
  test('rejects inappropriate terms after accent and digit normalization', () {
    expect(contemTermoInadequado('mensagem com MERDA'), isTrue);
    expect(contemTermoInadequado('mensagem com porrã'), isTrue);
    expect(contemTermoInadequado('texto m3rd4'), isTrue);
  });

  test(
    'does not reject ordinary words containing similar letter sequences',
    () {
      expect(
        contemTermoInadequado('O culto pela família e pela saúde'),
        isFalse,
      );
    },
  );

  test('reads hidden state and preserves it when copying a prayer request', () {
    final request = PedidoOracao.deMapa({
      'id': 'pedido-1',
      'nome_autor': 'Pessoa',
      'pedido': 'Pedido de oração',
      'categoria': 'Família',
      'criado_em': '2026-11-02T10:00:00Z',
      'quantidade_oracoes': 2,
      'anonimo': false,
      'oculto': true,
    });

    expect(request.oculto, isTrue);
    expect(request.copyWith(oculto: false).oculto, isFalse);
  });

  test('leaves creation time and prayer count to database defaults', () {
    final request = PedidoOracao(
      identificador: 'local-1',
      nomeAutor: 'Pessoa',
      pedido: 'Pedido de oração',
      categoria: 'Família',
      dataCriacao: DateTime(2026, 11, 13, 14),
    );

    expect(request.paraMapaDoBanco(), {
      'nome_autor': 'Pessoa',
      'pedido': 'Pedido de oração',
      'categoria': 'Família',
      'anonimo': false,
    });
  });
}
