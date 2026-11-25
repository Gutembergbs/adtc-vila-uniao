class DepartmentRosterMember {
  final String id;
  final String name;
  final String role;
  final String? photoPath;
  final String? photoUrl;

  const DepartmentRosterMember({
    required this.id,
    required this.name,
    required this.role,
    this.photoPath,
    this.photoUrl,
  });

  List<String> get roles => role
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();

  factory DepartmentRosterMember.fromDatabase(Map<String, dynamic> row) =>
      DepartmentRosterMember(
        id: row['membro_id'] as String,
        name: row['nome_exibicao'] as String,
        role: row['funcoes'] as String? ?? '',
        photoPath: row['foto_path'] as String?,
      );

  DepartmentRosterMember copyWithPhotoUrl(String? url) =>
      DepartmentRosterMember(
        id: id,
        name: name,
        role: role,
        photoPath: photoPath,
        photoUrl: url,
      );
}
