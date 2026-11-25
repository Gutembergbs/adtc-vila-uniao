import 'package:adtc_vila_uniao/models/monthly_birthday.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads a monthly birthday without exposing the birth year', () {
    final birthday = MonthlyBirthday.fromDatabase({
      'nome': 'Ana Souza',
      'dia': 15,
      'foto_path': 'member-1/perfil',
    }, photoUrl: 'https://example.test/member-photo');

    expect(birthday.name, 'Ana Souza');
    expect(birthday.day, 15);
    expect(birthday.photoUrl, 'https://example.test/member-photo');
  });

  test('allows birthdays without an uploaded profile photo', () {
    final birthday = MonthlyBirthday.fromDatabase({
      'nome': 'Bruno Lima',
      'dia': 22,
      'foto_path': null,
    });

    expect(birthday.photoUrl, isNull);
  });
}
