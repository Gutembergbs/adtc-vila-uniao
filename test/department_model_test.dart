import 'package:adtc_vila_uniao/models/department.dart';
import 'package:adtc_vila_uniao/models/department_leader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads department leader contact details', () {
    final leader = DepartmentLeader.fromDatabase({
      'nome_exibicao': 'Líder do grupo',
      'email_contato': 'lider@example.com',
    });

    expect(leader.name, 'Líder do grupo');
    expect(leader.email, 'lider@example.com');
  });

  test('reads and writes the conjunto history database field', () {
    final department = Department.fromDatabase({
      'id': 'jovens',
      'nome': 'Departamento de Jovens',
      'ordem': 3,
      'nome_conjunto': 'Celebra',
      'historico_conjunto': 'Fundado em 2010.',
      'descricao': 'Grupo de jovens.',
      'responsabilidades': <String>['Louvor'],
      'responsavel': 'Liderança',
      'horario_reuniao': 'Sábado',
      'icone': Icons.groups_rounded.codePoint,
      'cor': Colors.blue.toARGB32(),
      'tags': <String>['Jovens'],
      'instagram': '@celebra',
    });

    expect(department.conjuntoHistory, 'Fundado em 2010.');
    expect(department.toDatabase()['historico_conjunto'], 'Fundado em 2010.');
    expect(department.order, 3);
    expect(department.toDatabase()['ordem'], 3);
    expect(department.copyWith(order: 1).order, 1);
  });

  test('accepts rows without conjunto history', () {
    final department = Department.fromDatabase({
      'id': 'jovens',
      'nome': 'Departamento de Jovens',
      'nome_conjunto': null,
      'descricao': 'Grupo de jovens.',
      'responsabilidades': <String>[],
      'responsavel': 'Liderança',
      'horario_reuniao': 'Sábado',
      'icone': Icons.groups_rounded.codePoint,
      'cor': Colors.blue.toARGB32(),
      'tags': <String>[],
      'instagram': null,
    });

    expect(department.conjuntoHistory, isNull);
    expect(department.order, 0);
  });
}
