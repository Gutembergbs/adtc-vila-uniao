class Announcement {
  final String id;
  final String title;
  final String summary;
  final String content;
  final String date;
  final String
  category; // 'Aviso Geral', 'Escala', 'Liderança', 'Pastoral', 'Santa Ceia'
  final bool isMembersOnly;
  final String? actionUrl;
  final String? notificationId;
  final String? eventId;
  final bool notificationSent;
  final bool isRead;

  const Announcement({
    required this.id,
    required this.title,
    required this.summary,
    required this.content,
    required this.date,
    required this.category,
    this.isMembersOnly = false,
    this.actionUrl,
    this.notificationId,
    this.eventId,
    this.notificationSent = false,
    this.isRead = false,
  });

  factory Announcement.fromDatabase(Map<String, dynamic> row) => Announcement(
    id: row['id'] as String,
    title: row['titulo'] as String,
    summary: row['resumo'] as String,
    content: row['conteudo'] as String,
    date: row['data_exibicao'] as String,
    category: row['categoria'] as String,
    isMembersOnly: row['somente_membros'] as bool? ?? true,
    actionUrl: row['url_acao'] as String?,
  );

  factory Announcement.fromMemberNoticeDatabase(Map<String, dynamic> row) =>
      Announcement(
        id: 'membro_${row['id']}',
        title: row['titulo'] as String,
        summary: row['resumo'] as String? ?? '',
        content: row['conteudo'] as String,
        date: (row['criado_em'] as String).split('T').first,
        category: row['categoria'] as String? ?? 'Pessoal',
        isMembersOnly: true,
        isRead: row['visualizado_em'] != null,
      );

  factory Announcement.fromNotificationDatabase(Map<String, dynamic> row) =>
      Announcement(
        id: 'notificacao_${row['id']}',
        title: row['titulo'] as String,
        summary: row['resumo'] as String? ?? '',
        content: row['conteudo'] as String,
        date: (row['criado_em'] as String).split('T').first,
        category: row['categoria'] as String? ?? 'Geral',
        isMembersOnly: true,
        notificationId: row['id'] as String,
        eventId: row['evento_id'] as String?,
        notificationSent: row['enviado_em'] != null,
      );

  Announcement copyWith({bool? isRead}) => Announcement(
    id: id,
    title: title,
    summary: summary,
    content: content,
    date: date,
    category: category,
    isMembersOnly: isMembersOnly,
    actionUrl: actionUrl,
    notificationId: notificationId,
    eventId: eventId,
    notificationSent: notificationSent,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toDatabase() => {
    'id': id,
    'titulo': title,
    'resumo': summary,
    'conteudo': content,
    'data_exibicao': date,
    'categoria': category,
    'somente_membros': isMembersOnly,
    'url_acao': actionUrl,
  };
}
