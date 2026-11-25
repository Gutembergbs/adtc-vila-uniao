class ScaleItem {
  final String id;
  final String serviceName;
  final String date;
  final String time;
  final String department;
  final List<String> volunteers;
  final String observation;

  const ScaleItem({
    required this.id,
    required this.serviceName,
    required this.date,
    required this.time,
    required this.department,
    required this.volunteers,
    this.observation = '',
  });

  /// Converte uma linha da tabela `escalas` para o modelo do portal.
  factory ScaleItem.fromDatabase(Map<String, dynamic> row) => ScaleItem(
    id: row['id'] as String,
    serviceName: row['nome_culto'] as String,
    date: row['data'] as String,
    time: row['horario'] as String,
    department: row['departamento'] as String,
    volunteers: List<String>.from(row['voluntarios'] as List),
    observation: row['observacao'] as String? ?? '',
  );

  /// Converte a escala para os nomes das colunas do Supabase.
  Map<String, dynamic> toDatabase() => {
    'id': id,
    'nome_culto': serviceName,
    'data': date,
    'horario': time,
    'departamento': department,
    'voluntarios': volunteers,
    'observacao': observation,
  };
}
