import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/models/user_profile.dart';

void main() {
  test('reads member departments and administrator status', () {
    final member = UserProfile.fromDatabase({
      'usuario_id': 'user-1',
      'nome': 'Maria da Silva',
      'apelido': 'Irmã Maria',
      'email': 'maria@example.com',
      'telefone': '',
      'departamento': 'Louvor; Intercessão',
      'congregacao': 'ADTC Vila União',
      'data_batismo': null,
      'data_nascimento': '1995-08-21',
      'matricula': 12,
      'foto_path': 'user-1/perfil',
    }, isAdmin: true);

    expect(member.departments, ['Louvor', 'Intercessão']);
    expect(member.nickname, 'Irmã Maria');
    expect(member.displayName, 'Irmã Maria');
    expect(member.photoPath, 'user-1/perfil');
    expect(member.birthDate, '1995-08-21');
    expect(member.isAdmin, isTrue);
    expect(member.toJson()['isAdmin'], isTrue);
  });

  test('uses the full name when nickname is absent and reads old JSON', () {
    final member = UserProfile.fromDatabase({
      'usuario_id': 'user-2',
      'nome': 'João da Silva',
      'email': 'joao@example.com',
    });

    expect(member.displayName, 'João da Silva');
    expect(
      UserProfile.fromJson({
        'id': 'user-2',
        'name': 'João da Silva',
        'email': 'joao@example.com',
        'phone': '',
        'role': 'membro',
      }).nickname,
      isNull,
    );
  });

  test('pending members do not receive member-only access', () {
    final member = UserProfile.fromDatabase({
      'usuario_id': 'pending-user',
      'nome': 'Membro pendente',
      'email': 'pending@example.com',
      'ativo': false,
      'status_acesso': 'pendente',
    });

    expect(member.isMember, isTrue);
    expect(member.hasApprovedMemberAccess, isFalse);
    expect(member.accessStatus, 'pendente');
  });

  test('registered visitors are distinct from guest mode', () {
    final visitor = UserProfile.fromVisitorDatabase({
      'usuario_id': 'visitor-user',
      'nome': 'Pessoa visitante',
      'email': 'visitor@example.com',
      'telefone': '123',
    });

    expect(visitor.isVisitor, isTrue);
    expect(visitor.hasApprovedMemberAccess, isFalse);
    expect(visitor.id, 'visitor-user');
  });
}
