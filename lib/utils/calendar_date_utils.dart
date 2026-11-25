List<DateTime?> monthCalendarDates(DateTime month) {
  final firstDay = DateTime(month.year, month.month, 1);
  final dayCount = DateTime(month.year, month.month + 1, 0).day;
  final sundayBasedOffset = firstDay.weekday % DateTime.daysPerWeek;

  return List<DateTime?>.generate(DateTime.daysPerWeek * 6, (index) {
    final day = index - sundayBasedOffset + 1;
    return day >= 1 && day <= dayCount
        ? DateTime(month.year, month.month, day)
        : null;
  });
}
