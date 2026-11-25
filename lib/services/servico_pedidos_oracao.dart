import 'package:supabase_flutter/supabase_flutter.dart';

import '../configuracao_supabase.dart';
import '../models/pedido_oracao.dart';
import '../utils/validacao_pedido_oracao.dart';
import 'data_service.dart';

/// Centraliza leitura e publicação de pedidos de oração.
class ServicoPedidosOracao {
  static const _camposPedido =
      'id,nome_autor,pedido,categoria,criado_em,quantidade_oracoes,anonimo,oculto';

  /// Busca pedidos no Supabase ou usa exemplos locais sem configuração.
  static Future<List<PedidoOracao>> listarPedidos() async {
    if (!supabaseInicializado) {
      return List<PedidoOracao>.from(DataService.pedidosIniciaisOracao);
    }

    final resposta = await Supabase.instance.client
        .from('pedidos_oracao')
        .select(_camposPedido)
        .order('criado_em', ascending: false);

    return (resposta as List)
        .map((linha) => PedidoOracao.deMapa(Map<String, dynamic>.from(linha)))
        .toList();
  }

  /// Lista todos os pedidos para moderação no painel administrativo.
  static Future<List<PedidoOracao>> listarPedidosAdmin() async {
    if (!supabaseInicializado) {
      return List<PedidoOracao>.from(DataService.pedidosIniciaisOracao);
    }

    final resposta = await Supabase.instance.client
        .from('pedidos_oracao')
        .select(_camposPedido)
        .order('criado_em', ascending: false);

    return (resposta as List)
        .map((linha) => PedidoOracao.deMapa(Map<String, dynamic>.from(linha)))
        .toList();
  }

  /// Salva um pedido e devolve a linha criada pelo banco.
  static Future<PedidoOracao> publicarPedido(PedidoOracao pedido) async {
    if (contemTermoInadequado('${pedido.nomeAutor} ${pedido.pedido}')) {
      throw const ConteudoInadequadoException();
    }
    if (!supabaseInicializado) return pedido;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      await client.from('pedidos_oracao').insert(pedido.paraMapaDoBanco());
      return pedido;
    }

    final resposta = await client
        .from('pedidos_oracao')
        .insert(pedido.paraMapaDoBanco())
        .select(_camposPedido)
        .single();

    return PedidoOracao.deMapa(Map<String, dynamic>.from(resposta));
  }

  static Future<Set<String>> listarIntercessoesDoUsuario(
    List<String> pedidoIds,
  ) async {
    if (!supabaseInicializado ||
        pedidoIds.isEmpty ||
        Supabase.instance.client.auth.currentUser == null) {
      return {};
    }

    final rows = await Supabase.instance.client
        .from('intercessoes_pedidos')
        .select('pedido_id')
        .inFilter('pedido_id', pedidoIds);
    return (rows as List)
        .map((row) => (row as Map<String, dynamic>)['pedido_id'] as String)
        .toSet();
  }

  static Future<void> definirIntercessao({
    required String pedidoId,
    required bool orando,
  }) async {
    if (!supabaseInicializado) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Entre na sua conta para sinalizar que está orando.');
    }

    final table = Supabase.instance.client.from('intercessoes_pedidos');
    if (orando) {
      await table.upsert(
        {'pedido_id': pedidoId, 'usuario_id': userId},
        onConflict: 'pedido_id,usuario_id',
        ignoreDuplicates: true,
      );
    } else {
      await table.delete().eq('pedido_id', pedidoId).eq('usuario_id', userId);
    }
  }

  static Future<void> definirOculto({
    required String identificador,
    required bool oculto,
  }) async {
    if (!supabaseInicializado) {
      throw StateError('Configure o Supabase para moderar pedidos.');
    }
    await Supabase.instance.client
        .from('pedidos_oracao')
        .update({'oculto': oculto})
        .eq('id', identificador)
        .select('id')
        .single();
  }

  static Future<void> excluirPedido(String identificador) async {
    if (!supabaseInicializado) {
      throw StateError('Configure o Supabase para excluir pedidos.');
    }
    await Supabase.instance.client
        .from('pedidos_oracao')
        .delete()
        .eq('id', identificador)
        .select('id')
        .single();
  }
}
