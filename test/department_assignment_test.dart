import 'package:adtc_vila_uniao/models/department_assignment.dart';
import 'package:adtc_vila_uniao/models/department_roster_member.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads department role assignments from database rows', () {
    final assignment = DepartmentAssignment.fromDatabase({
      'id': 'assignment-1',
      'departamento_id': 'jovens',
      'membro_id': 'member-1',
      'cargo': 'Regente',
    });

    expect(assignment.departmentId, 'jovens');
    expect(assignment.memberId, 'member-1');
    expect(assignment.role, 'Regente');
    expect(assignment.toDatabase()['cargo'], 'Regente');
  });

  test('reads department roster names and assigned roles', () {
    final member = DepartmentRosterMember.fromDatabase({
      'membro_id': 'member-1',
      'nome_exibicao': 'Ana Oliveira',
      'funcoes': 'Regente, Professora',
      'foto_path': 'user-1/profile.jpg',
    });

    expect(member.id, 'member-1');
    expect(member.name, 'Ana Oliveira');
    expect(member.role, 'Regente, Professora');
    expect(member.roles, ['Regente', 'Professora']);
    expect(member.photoPath, 'user-1/profile.jpg');
  });
}
