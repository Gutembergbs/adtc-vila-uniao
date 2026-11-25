class MonthlyBirthday {
  final String name;
  final int day;
  final String? photoUrl;

  const MonthlyBirthday({required this.name, required this.day, this.photoUrl});

  factory MonthlyBirthday.fromDatabase(
    Map<String, dynamic> row, {
    String? photoUrl,
  }) => MonthlyBirthday(
    name: row['nome'] as String,
    day: row['dia'] as int,
    photoUrl: photoUrl,
  );
}
