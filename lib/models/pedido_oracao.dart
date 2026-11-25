/// Representa um pedido publicado no mural de oração.
class PedidoOracao {
  /// Identificador retornado pelo banco ou criado para dados locais.
  final String identificador;

  /// Nome exibido no mural; pedidos anônimos ocultam este valor na tela.
  final String nomeAutor;

  /// Texto compartilhado pela pessoa que pediu oração.
  final String pedido;

  /// Categoria usada para filtrar os pedidos no mural.
  final String categoria;

  /// Data de publicação do pedido.
  final DateTime dataCriacao;

  /// Quantidade de pessoas que sinalizaram que estão orando.
  int quantidadeOracoes;

  /// Define se o nome do autor deve permanecer oculto.
  final bool anonimo;

  /// Define se o pedido está oculto do mural público.
  final bool oculto;

  /// Indica se a pessoa usuária atual já sinalizou que está orando.
  bool usuarioEstaOrando;

  /// Cria um pedido local ou carregado do banco.
  PedidoOracao({
    required this.identificador,
    required this.nomeAutor,
    required this.pedido,
    required this.categoria,
    required this.dataCriacao,
    this.quantidadeOracoes = 0,
    this.anonimo = false,
    this.oculto = false,
    this.usuarioEstaOrando = false,
  });

  /// Converte uma linha da tabela `pedidos_oracao` para o modelo do app.
  factory PedidoOracao.deMapa(Map<String, dynamic> mapa) {
    return PedidoOracao(
      identificador: mapa['id'].toString(),
      nomeAutor: mapa['nome_autor'] as String? ?? 'Membro/Visitante',
      pedido: mapa['pedido'] as String? ?? '',
      categoria: mapa['categoria'] as String? ?? 'Outros',
      dataCriacao: DateTime.parse(mapa['criado_em'].toString()),
      quantidadeOracoes: mapa['quantidade_oracoes'] as int? ?? 0,
      anonimo: mapa['anonimo'] as bool? ?? false,
      oculto: mapa['oculto'] as bool? ?? false,
    );
  }

  PedidoOracao copyWith({bool? oculto}) => PedidoOracao(
    identificador: identificador,
    nomeAutor: nomeAutor,
    pedido: pedido,
    categoria: categoria,
    dataCriacao: dataCriacao,
    quantidadeOracoes: quantidadeOracoes,
    anonimo: anonimo,
    oculto: oculto ?? this.oculto,
    usuarioEstaOrando: usuarioEstaOrando,
  );

  /// Produz somente os campos aceitos ao inserir uma linha no Supabase.
  Map<String, dynamic> paraMapaDoBanco() => {
    'nome_autor': nomeAutor,
    'pedido': pedido,
    'categoria': categoria,
    'anonimo': anonimo,
  };
}
