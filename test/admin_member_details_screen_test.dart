import 'package:adtc_vila_uniao/models/department.dart';
import 'package:adtc_vila_uniao/models/department_assignment.dart';
import 'package:adtc_vila_uniao/models/member_record.dart';
import 'package:adtc_vila_uniao/screens/admin_member_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const member = MemberRecord(
    id: 'member-1',
    email: 'member@example.com',
    name: 'Ana Oliveira',
  );
  const department = Department(
    id: 'jovens',
    name: 'Jovens',
    description: '',
    responsibilities: [],
    leaderName: '',
    meetingSchedule: '',
    icon: Icons.groups,
    color: Colors.blue,
    tags: [],
  );
  const assignment = DepartmentAssignment(
    id: 'assignment-1',
    departmentId: 'jovens',
    memberId: 'member-1',
    role: 'Regente',
  );

  testWidgets('cancelling edit role leaves details open without errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMemberDetailsScreen(
          member: member,
          departments: const [department],
          assignments: const [assignment],
          onAssignmentsChanged: () async {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar função'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Regente'), findsOneWidget);
    expect(find.text('Editar função'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelling new department role leaves details open safely', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMemberDetailsScreen(
          member: member,
          departments: const [department],
          assignments: const [],
          onAssignmentsChanged: () async {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Atribuir departamento e função'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Nenhum departamento ou função atribuída.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('linked members can be converted to visitors', (tester) async {
    var converted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AdminMemberDetailsScreen(
          member: const MemberRecord(
            id: 'member-1',
            userId: 'user-1',
            email: 'member@example.com',
            name: 'Ana Oliveira',
          ),
          departments: const [],
          assignments: const [],
          onAssignmentsChanged: () async {},
          onEdit: () {},
          onDelete: () {},
          onConvertToVisitor: () async {
            converted = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Transformar em visitante'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Transformar em visitante'));
    await tester.pumpAndSettle();

    expect(converted, isTrue);
    expect(tester.takeException(), isNull);
  });
}
