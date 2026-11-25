import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../configuracao_supabase.dart';
import '../models/pedido_oracao.dart';
import '../services/auth_service.dart';
import '../services/servico_pedidos_oracao.dart';
import '../utils/validacao_pedido_oracao.dart';

/// Exibe os pedidos de oração e permite publicar novos pedidos.
class TelaPedidosOracao extends StatefulWidget {
  /// Serviço de autenticação local usado para preencher o nome do autor.
  final AuthService servicoAutenticacao;

  /// Cria o mural associado ao serviço de autenticação atual.
  const TelaPedidosOracao({super.key, required this.servicoAutenticacao});

  @override
  State<TelaPedidosOracao> createState() => _EstadoTelaPedidosOracao();
}

/// Controla carregamento, filtragem, publicação e intercessão no mural.
class _EstadoTelaPedidosOracao extends State<TelaPedidosOracao> {
  /// Os exemplos locais são substituídos pelos dados do banco quando disponíveis.
  final List<PedidoOracao> _pedidos = [];

  /// Categorias exibidas no seletor e no formulário de publicação.
  final List<String> _categorias = [
    'Todos',
    'Família',
    'Saúde',
    'Emprego',
    'Espiritual',
    'Gratidão',
    'Outros',
  ];

  String _categoriaSelecionada = 'Todos';
  bool _carregando = true;
  final Set<String> _pedidosAtualizandoIntercessao = {};
  RealtimeChannel? _canalPedidosOracao;
  Timer? _timerAtualizacaoPedidos;
  String? _erroRealtime;

  @override
  void initState() {
    super.initState();
    widget.servicoAutenticacao.addListener(_handleAuthenticationChanged);
    _assinarAtualizacoesDosPedidos();
    _carregarPedidos();
  }

  @override
  void dispose() {
    _timerAtualizacaoPedidos?.cancel();
    final channel = _canalPedidosOracao;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    widget.servicoAutenticacao.removeListener(_handleAuthenticationChanged);
    super.dispose();
  }

  void _assinarAtualizacoesDosPedidos() {
    if (!supabaseInicializado) return;

    _canalPedidosOracao = Supabase.instance.client
        .channel('mural-oracao-${DateTime.now().microsecondsSinceEpoch}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'pedidos_oracao',
          callback: _agendarAtualizacaoDosPedidos,
        )
        .subscribe((status, error) {
          if (!mounted) return;
          setState(() {
            _erroRealtime = status == RealtimeSubscribeStatus.subscribed
                ? null
                : error?.toString() ?? 'Conexão em tempo real: $status';
          });
        });
  }

  void _agendarAtualizacaoDosPedidos(PostgresChangePayload _) {
    _timerAtualizacaoPedidos?.cancel();
    _timerAtualizacaoPedidos = Timer(
      const Duration(milliseconds: 300),
      _carregarPedidos,
    );
  }

  void _handleAuthenticationChanged() {
    if (!widget.servicoAutenticacao.isAuthenticated) {
      setState(() {
        _pedidos.clear();
        _carregando = false;
      });
      return;
    }
    _carregarPedidos();
  }

  /// Carrega pedidos reais; dados de exemplo são usados apenas sem Supabase.
  Future<void> _carregarPedidos() async {
    if (!widget.servicoAutenticacao.isAuthenticated) {
      if (mounted) setState(() => _carregando = false);
      return;
    }
    final userId = widget.servicoAutenticacao.currentUser?.id;
    try {
      final pedidosCarregados = await ServicoPedidosOracao.listarPedidos();
      final intercessoes =
          await ServicoPedidosOracao.listarIntercessoesDoUsuario(
            pedidosCarregados.map((pedido) => pedido.identificador).toList(),
          );
      if (!mounted ||
          !widget.servicoAutenticacao.isAuthenticated ||
          widget.servicoAutenticacao.currentUser?.id != userId) {
        return;
      }

      for (final pedido in pedidosCarregados) {
        pedido.usuarioEstaOrando = intercessoes.contains(pedido.identificador);
      }

      setState(() {
        _pedidos
          ..clear()
          ..addAll(pedidosCarregados);
        _carregando = false;
      });
    } catch (error) {
      if (!mounted ||
          !widget.servicoAutenticacao.isAuthenticated ||
          widget.servicoAutenticacao.currentUser?.id != userId) {
        return;
      }

      setState(() {
        _pedidos.clear();
        _carregando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível carregar os pedidos: $error')),
      );
    }
  }

  /// Abre o formulário e publica o pedido no Supabase quando configurado.
  Future<void> _abrirFormularioDePedido() async {
    final chaveFormulario = GlobalKey<FormState>();
    String textoPedido = '';
    String categoria = 'Família';
    final isAuthenticated = widget.servicoAutenticacao.isAuthenticated;
    bool anonimo = !isAuthenticated;
    bool enviando = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (contextFolha) => StatefulBuilder(
        builder: (context, atualizarFolha) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Form(
            key: chaveFormulario,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Cabeçalho do formulário e ação para fechar a folha.
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Novo Pedido de Oração',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(contextFolha),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Sua congregação estará intercedendo por você nos cultos e na oração do meio-dia.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'O mural é visível somente para membros conectados. Pedidos enviados sem login serão anônimos.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: categoria,
                  decoration: const InputDecoration(
                    labelText: 'Categoria',
                    prefixIcon: Icon(Icons.category_outlined),
                  ),
                  items: _categorias
                      .where((item) => item != 'Todos')
                      .map(
                        (item) =>
                            DropdownMenuItem(value: item, child: Text(item)),
                      )
                      .toList(),
                  onChanged: (valor) {
                    if (valor != null) {
                      atualizarFolha(() => categoria = valor);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  maxLength: 2000,
                  maxLines: 3,
                  onChanged: (valor) => textoPedido = valor,
                  decoration: const InputDecoration(
                    labelText: 'Escreva seu pedido ou motivo de clamor *',
                    alignLabelWithHint: true,
                  ),
                  validator: (valor) {
                    if (valor == null || valor.trim().isEmpty) {
                      return 'Por favor, descreva seu pedido.';
                    }
                    if (contemTermoInadequado(valor)) {
                      return 'Revise o texto: ele contém linguagem inadequada.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                if (isAuthenticated)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Publicar de forma anônima',
                      style: TextStyle(fontSize: 13.5),
                    ),
                    value: anonimo,
                    onChanged: (valor) {
                      atualizarFolha(() => anonimo = valor);
                    },
                  ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: enviando
                        ? null
                        : () async {
                            if (!chaveFormulario.currentState!.validate()) {
                              return;
                            }

                            atualizarFolha(() => enviando = true);
                            final usuarioAtual =
                                widget.servicoAutenticacao.currentUser;
                            final novoPedido = PedidoOracao(
                              identificador:
                                  'local_${DateTime.now().millisecondsSinceEpoch}',
                              nomeAutor: anonimo
                                  ? 'Membro anônimo'
                                  : (usuarioAtual?.name ?? 'Membro/Visitante'),
                              pedido: textoPedido.trim(),
                              categoria: categoria,
                              dataCriacao: DateTime.now(),
                              anonimo: anonimo,
                            );

                            try {
                              final pedidoSalvo =
                                  await ServicoPedidosOracao.publicarPedido(
                                    novoPedido,
                                  );
                              if (!mounted) return;

                              setState(() => _pedidos.insert(0, pedidoSalvo));
                              if (contextFolha.mounted) {
                                Navigator.pop(contextFolha);
                              }
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Pedido publicado! A congregação estará orando por você.',
                                  ),
                                  backgroundColor: Color(0xFF0F766E),
                                ),
                              );
                            } catch (error) {
                              if (!context.mounted) return;
                              if (contextFolha.mounted) {
                                atualizarFolha(() => enviando = false);
                              }
                              final mensagem =
                                  error is ConteudoInadequadoException ||
                                      error.toString().contains(
                                        'linguagem inadequada',
                                      )
                                  ? 'O texto contém linguagem inadequada. Revise o pedido antes de publicar.'
                                  : 'Não foi possível publicar o pedido: $error';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(mensagem),
                                  backgroundColor: Color(0xFFB42318),
                                ),
                              );
                            }
                          },
                    icon: enviando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(enviando ? 'Publicando...' : 'Enviar Pedido'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Alterna o estado de intercessão na sessão atual.
  Future<void> _alternarIntercessao(PedidoOracao pedido) async {
    if (_pedidosAtualizandoIntercessao.contains(pedido.identificador)) return;

    final orandoAntes = pedido.usuarioEstaOrando;
    final quantidadeAntes = pedido.quantidadeOracoes;
    final novaIntercessao = !orandoAntes;
    var intercessaoAtualizada = false;
    setState(() {
      _pedidosAtualizandoIntercessao.add(pedido.identificador);
      pedido.usuarioEstaOrando = novaIntercessao;
      pedido.quantidadeOracoes = (quantidadeAntes + (novaIntercessao ? 1 : -1))
          .clamp(0, 9999);
    });

    try {
      await ServicoPedidosOracao.definirIntercessao(
        pedidoId: pedido.identificador,
        orando: novaIntercessao,
      );
      intercessaoAtualizada = true;
    } catch (error) {
      if (!mounted) return;
      setState(() {
        pedido.usuarioEstaOrando = orandoAntes;
        pedido.quantidadeOracoes = quantidadeAntes;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Não foi possível atualizar sua oração: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _pedidosAtualizandoIntercessao.remove(pedido.identificador);
        });
      }
    }

    if (mounted && intercessaoAtualizada && novaIntercessao) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Deus abençoe sua intercessão! Clamando juntos.'),
          duration: Duration(seconds: 2),
          backgroundColor: Color(0xFF0F766E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAuthenticated = widget.servicoAutenticacao.isAuthenticated;
    // Filtra a lista sem alterar a ordem dos pedidos carregados.
    final pedidosFiltrados = _categoriaSelecionada == 'Todos'
        ? _pedidos
        : _pedidos
              .where((pedido) => pedido.categoria == _categoriaSelecionada)
              .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Mural de Oração')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _abrirFormularioDePedido,
        backgroundColor: const Color(0xFF0F766E),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Novo Pedido'),
      ),
      body: Column(
        children: [
          if (_erroRealtime != null)
            MaterialBanner(
              content: Text(
                'As contagens podem não atualizar em tempo real: $_erroRealtime',
              ),
              leading: const Icon(Icons.wifi_off_rounded),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _erroRealtime = null),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          // Fundo claro e estados dos chips com contraste consistente.
          if (isAuthenticated)
            Container(
              color: const Color(0xFFF1F5F3),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _categorias.map((categoria) {
                    final selecionada = _categoriaSelecionada == categoria;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(categoria),
                        selected: selecionada,
                        selectedColor: const Color(0xFF0F766E),
                        backgroundColor: Colors.white,
                        side: BorderSide(
                          color: selecionada
                              ? const Color(0xFF0F766E)
                              : const Color(0xFFCBD5D1),
                        ),
                        labelStyle: TextStyle(
                          color: selecionada
                              ? Colors.white
                              : const Color(0xFF334155),
                          fontWeight: selecionada
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) =>
                            setState(() => _categoriaSelecionada = categoria),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          Expanded(
            child: !isAuthenticated
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        widget.servicoAutenticacao.isAwaitingApproval
                            ? 'Seu cadastro está aguardando autorização da administração para consultar os pedidos de oração.'
                            : 'Entre na sua conta para consultar os pedidos de oração.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : _carregando
                ? const Center(child: CircularProgressIndicator())
                : pedidosFiltrados.isEmpty
                ? Center(
                    child: Text(
                      'Nenhum pedido nesta categoria.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                    itemCount: pedidosFiltrados.length,
                    itemBuilder: (context, indice) =>
                        _construirCartaoPedido(pedidosFiltrados[indice]),
                  ),
          ),
        ],
      ),
    );
  }

  /// Monta o conteúdo visual de um único pedido.
  Widget _construirCartaoPedido(PedidoOracao pedido) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFE6F4F1),
                        child: Icon(
                          Icons.person_rounded,
                          size: 16,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pedido.anonimo ? 'Pedido anônimo' : pedido.nomeAutor,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.5,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    pedido.categoria,
                    style: const TextStyle(
                      color: Color(0xFF115E59),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              pedido.pedido,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade800,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Publicado em ${DateFormat("dd/MM/yyyy 'às' HH:mm").format(pedido.dataCriacao.toLocal())}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${pedido.quantidadeOracoes} pessoa(s) em oração',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed:
                      _pedidosAtualizandoIntercessao.contains(
                        pedido.identificador,
                      )
                      ? null
                      : () => _alternarIntercessao(pedido),
                  icon: Icon(
                    pedido.usuarioEstaOrando
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 18,
                    color: pedido.usuarioEstaOrando
                        ? const Color(0xFFB42318)
                        : const Color(0xFF0F766E),
                  ),
                  label: Text(
                    pedido.usuarioEstaOrando ? 'Orando' : 'Vou Orar',
                    style: TextStyle(
                      color: pedido.usuarioEstaOrando
                          ? const Color(0xFFB42318)
                          : const Color(0xFF0F766E),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
