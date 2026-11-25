class DepartmentLeader {
  final String name;
  final String? email;

  const DepartmentLeader({required this.name, this.email});

  factory DepartmentLeader.fromDatabase(Map<String, dynamic> row) =>
      DepartmentLeader(
        name: row['nome_exibicao'] as String,
        email: row['email_contato'] as String?,
      );
}
