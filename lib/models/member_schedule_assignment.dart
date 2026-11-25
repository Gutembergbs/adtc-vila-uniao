class MemberScheduleAssignment {
  final String id;
  final String memberId;
  final String departmentId;
  final String eventId;
  final DateTime date;

  const MemberScheduleAssignment({
    required this.id,
    required this.memberId,
    required this.departmentId,
    required this.eventId,
    required this.date,
  });

  factory MemberScheduleAssignment.fromDatabase(Map<String, dynamic> row) =>
      MemberScheduleAssignment(
        id: row['id'] as String,
        memberId: row['membro_id'] as String,
        departmentId: row['departamento_id'] as String,
        eventId: row['evento_id'] as String,
        date: DateTime.parse(row['data'] as String),
      );
}
