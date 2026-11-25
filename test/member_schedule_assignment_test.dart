import 'package:adtc_vila_uniao/models/member_schedule_assignment.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a member event assignment and date from the database', () {
    final assignment = MemberScheduleAssignment.fromDatabase({
      'id': 'assignment-1',
      'membro_id': 'member-1',
      'departamento_id': 'jovens',
      'evento_id': 'culto-jovens',
      'data': '2026-10-28',
    });

    expect(assignment.memberId, 'member-1');
    expect(assignment.departmentId, 'jovens');
    expect(assignment.eventId, 'culto-jovens');
    expect(assignment.date, DateTime(2026, 10, 28));
  });
}
