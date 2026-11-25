import 'package:adtc_vila_uniao/models/member_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads and saves optional member nickname', () {
    final member = MemberRecord.fromDatabase({
      'email': 'guto@example.com',
      'nome': 'Augusto Oliveira',
      'apelido': 'Ir. Guto',
    });

    expect(member.nickname, 'Ir. Guto');
    expect(member.toDatabase()['apelido'], 'Ir. Guto');
  });

  test('saves an empty nickname as null', () {
    const member = MemberRecord(
      email: 'guto@example.com',
      name: 'Augusto Oliveira',
    );

    expect(member.toDatabase()['apelido'], isNull);
  });

  test('supports preregistered members without app access email', () {
    final member = MemberRecord.fromDatabase({
      'id': 'member-child',
      'nome': 'Ana Oliveira',
      'email': null,
      'ativo': true,
    });

    expect(member.email, isEmpty);
    expect(member.toDatabase()['email'], isNull);
    expect(member.toDatabase()['ativo'], isTrue);
  });

  test('reads pending access and saves approval status', () {
    final member = MemberRecord.fromDatabase({
      'id': 'member-pending',
      'usuario_id': 'user-pending',
      'nome': 'Ana Oliveira',
      'ativo': false,
      'status_acesso': 'pendente',
    });

    expect(member.accessStatus, 'pendente');
    expect(member.isActive, isFalse);
    expect(member.toDatabase()['status_acesso'], 'pendente');
  });

  test('preserves member photo path when opening and saving a record', () {
    final member = MemberRecord.fromDatabase({
      'id': 'member-1',
      'nome': 'Ana Oliveira',
      'foto_path': 'user-1/profile.jpg',
    });

    expect(member.photoPath, 'user-1/profile.jpg');
    expect(member.toDatabase()['foto_path'], 'user-1/profile.jpg');
  });
}
