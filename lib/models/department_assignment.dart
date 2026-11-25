class DepartmentAssignment {
  final String id;
  final String departmentId;
  final String memberId;
  final String role;

  const DepartmentAssignment({
    required this.id,
    required this.departmentId,
    required this.memberId,
    required this.role,
  });

  factory DepartmentAssignment.fromDatabase(Map<String, dynamic> row) =>
      DepartmentAssignment(
        id: row['id']?.toString() ?? '',
        departmentId: row['departamento_id'] as String,
        memberId: row['membro_id'] as String,
        role: row['cargo'] as String,
      );

  Map<String, dynamic> toDatabase() => {
    if (id.isNotEmpty) 'id': id,
    'departamento_id': departmentId,
    'membro_id': memberId,
    'cargo': role.trim(),
  };
}
