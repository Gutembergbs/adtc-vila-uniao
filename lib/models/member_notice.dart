class MemberNotice {
  final String id;
  final String memberId;
  final String? departmentId;
  final String title;
  final String summary;
  final String content;
  final String category;
  final DateTime createdAt;
  final DateTime? viewedAt;

  const MemberNotice({
    required this.id,
    required this.memberId,
    required this.departmentId,
    required this.title,
    required this.summary,
    required this.content,
    required this.category,
    required this.createdAt,
    required this.viewedAt,
  });

  factory MemberNotice.fromDatabase(Map<String, dynamic> row) => MemberNotice(
    id: row['id'] as String,
    memberId: row['membro_id'] as String,
    departmentId: row['departamento_id'] as String?,
    title: row['titulo'] as String,
    summary: row['resumo'] as String? ?? '',
    content: row['conteudo'] as String,
    category: row['categoria'] as String? ?? 'Pessoal',
    createdAt: DateTime.parse(row['criado_em'] as String),
    viewedAt: row['visualizado_em'] == null
        ? null
        : DateTime.parse(row['visualizado_em'] as String),
  );
}
