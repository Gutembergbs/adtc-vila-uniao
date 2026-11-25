class UserProfile {
  final String id;
  final String name;
  final String? nickname;
  final String email;
  final String phone;
  final String role; // 'visitante', 'membro', 'lider', 'obreiro', 'pastor'
  final String? department;
  final String congregation;
  final String? baptismDate;
  final String? birthDate;
  final String? avatarInitials;
  final String? photoPath;
  final String? photoUrl;
  final String? membershipNumber;
  final bool isAdmin;
  final String accessStatus;

  const UserProfile({
    required this.id,
    required this.name,
    this.nickname,
    required this.email,
    required this.phone,
    required this.role,
    this.department,
    this.congregation = 'ADTC Vila União - Sobral',
    this.baptismDate,
    this.birthDate,
    this.avatarInitials,
    this.photoPath,
    this.photoUrl,
    this.membershipNumber,
    this.isAdmin = false,
    this.accessStatus = 'autorizado',
  });

  bool get isVisitor => role == 'visitante';
  bool get hasApprovedMemberAccess =>
      !isVisitor && accessStatus == 'autorizado';
  String get displayName =>
      nickname?.trim().isNotEmpty == true ? nickname!.trim() : name;
  bool get isMember => role != 'visitante';
  bool get isLeader => role == 'lider' || role == 'pastor' || role == 'obreiro';
  List<String> get departments => (department ?? '')
      .split(RegExp(r'[,;|]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toList();

  /// Cria o perfil exibido no app a partir da tabela `membros`.
  factory UserProfile.fromDatabase(
    Map<String, dynamic> row, {
    bool isAdmin = false,
    String? photoUrl,
  }) => UserProfile(
    id: row['usuario_id'] as String,
    name: row['nome'] as String,
    nickname: row['apelido'] as String?,
    email: row['email'] as String,
    phone: row['telefone'] as String? ?? '',
    role: 'membro',
    department: row['departamento'] as String?,
    congregation: row['congregacao'] as String? ?? 'ADTC Vila União - Sobral',
    baptismDate: row['data_batismo'] as String?,
    birthDate: row['data_nascimento'] as String?,
    photoPath: row['foto_path'] as String?,
    photoUrl: photoUrl,
    membershipNumber: row['matricula']?.toString(),
    isAdmin: isAdmin,
    accessStatus:
        row['status_acesso'] as String? ??
        ((row['ativo'] as bool? ?? true) ? 'autorizado' : 'bloqueado'),
  );

  factory UserProfile.fromVisitorDatabase(Map<String, dynamic> row) =>
      UserProfile(
        id: row['usuario_id'] as String,
        name: row['nome'] as String,
        email: row['email'] as String? ?? '',
        phone: row['telefone'] as String? ?? '',
        role: 'visitante',
        department: row['bairro'] as String?,
        isAdmin: false,
      );

  String get initials {
    if (avatarInitials != null && avatarInitials!.isNotEmpty) {
      return avatarInitials!;
    }
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'U';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'nickname': nickname,
    'email': email,
    'phone': phone,
    'role': role,
    'department': department,
    'congregation': congregation,
    'baptismDate': baptismDate,
    'birthDate': birthDate,
    'photoPath': photoPath,
    'membershipNumber': membershipNumber,
    'isAdmin': isAdmin,
    'accessStatus': accessStatus,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    nickname: json['nickname'] as String?,
    email: json['email'] as String,
    phone: json['phone'] as String,
    role: json['role'] as String,
    department: json['department'] as String?,
    congregation: json['congregation'] as String? ?? 'ADTC Vila União - Sobral',
    baptismDate: json['baptismDate'] as String?,
    birthDate: json['birthDate'] as String?,
    photoPath: json['photoPath'] as String?,
    membershipNumber: json['membershipNumber'] as String?,
    isAdmin: json['isAdmin'] as bool? ?? false,
    accessStatus: json['accessStatus'] as String? ?? 'autorizado',
  );
}
