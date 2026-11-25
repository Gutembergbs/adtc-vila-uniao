/// Dados cadastrais de um membro, com vínculo Auth opcional até o primeiro login.
class MemberRecord {
  final String? id;
  final String? userId;
  final String? membershipNumber;
  final String email;
  final String name;
  final String nickname;
  final String phone;
  final String department;
  final String? photoPath;
  final String congregation;
  final String baptismDate;
  final String birthDate;
  final bool isActive;
  final String accessStatus;

  const MemberRecord({
    this.id,
    this.userId,
    this.membershipNumber,
    required this.email,
    required this.name,
    this.nickname = '',
    this.phone = '',
    this.department = '',
    this.photoPath,
    this.congregation = 'ADTC Vila União - Sobral',
    this.baptismDate = '',
    this.birthDate = '',
    this.isActive = true,
    this.accessStatus = 'autorizado',
  });

  /// Lê os campos de uma linha da tabela `membros`.
  factory MemberRecord.fromDatabase(Map<String, dynamic> row) => MemberRecord(
    id: row['id'] as String?,
    userId: row['usuario_id'] as String?,
    membershipNumber: row['matricula']?.toString(),
    email: row['email'] as String? ?? '',
    name: row['nome'] as String,
    nickname: row['apelido'] as String? ?? '',
    phone: row['telefone'] as String? ?? '',
    department: row['departamento'] as String? ?? '',
    photoPath: row['foto_path'] as String?,
    congregation: row['congregacao'] as String? ?? 'ADTC Vila União - Sobral',
    baptismDate: row['data_batismo'] as String? ?? '',
    birthDate: row['data_nascimento'] as String? ?? '',
    isActive: row['ativo'] as bool? ?? true,
    accessStatus:
        row['status_acesso'] as String? ??
        ((row['ativo'] as bool? ?? true) ? 'autorizado' : 'bloqueado'),
  );

  /// Converte os dados para gravação administrativa sem alterar a matrícula.
  Map<String, dynamic> toDatabase() => {
    if (id != null) 'id': id,
    if (userId != null) 'usuario_id': userId,
    'email': email.trim().isEmpty ? null : email.trim().toLowerCase(),
    'nome': name.trim(),
    'apelido': nickname.trim().isEmpty ? null : nickname.trim(),
    'telefone': phone.trim(),
    'departamento': department.trim(),
    if (photoPath != null) 'foto_path': photoPath,
    'congregacao': congregation.trim(),
    'data_batismo': baptismDate.trim().isEmpty ? null : baptismDate.trim(),
    'data_nascimento': birthDate.trim().isEmpty ? null : birthDate.trim(),
    'ativo': isActive,
    'status_acesso': accessStatus,
  };
}
