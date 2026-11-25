import 'package:intl/intl.dart';

String formatMemberDate(String? value, {String fallback = 'Não informado'}) {
  final normalizedValue = value?.trim();
  if (normalizedValue == null || normalizedValue.isEmpty) return fallback;

  final date = DateTime.tryParse(normalizedValue) ?? _parseBrazilianDate(normalizedValue);
  if (date == null) return normalizedValue;
  return DateFormat('dd/MM/yyyy').format(date);
}

DateTime? _parseBrazilianDate(String value) {
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(value);
  } on FormatException {
    return null;
  }
}
