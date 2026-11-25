import 'package:flutter/material.dart';
import '../utils/material_icon_data.dart';

enum EventType { culto, oracao, ensaio, estudo, consagracao, missao, especial }

class ScheduleEvent {
  final String id;
  final String title;
  final String subtitle;
  final String time;
  final DateTime? eventDate;
  final String daysDescription;
  final int? dayOfWeek; // 1 = Segunda, 7 = Domingo, null = Diário / Vários
  final String location;
  final EventType type;
  final String? departmentId;
  final String?
  recurringCycle; // 'Diário', 'Semanal', '1º Domingo do Mês', etc.
  final IconData icon;
  final Color color;
  final String notes;
  final bool monthlyTheme;
  final String? attachmentPath;
  final String? attachmentName;
  final String? linkText;
  final String? linkUrl;

  const ScheduleEvent({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.time,
    this.eventDate,
    required this.daysDescription,
    this.dayOfWeek,
    required this.location,
    required this.type,
    this.departmentId,
    this.recurringCycle,
    required this.icon,
    required this.color,
    required this.notes,
    this.monthlyTheme = false,
    this.attachmentPath,
    this.attachmentName,
    this.linkText,
    this.linkUrl,
  });

  ScheduleEvent copyWithAttachment({
    String? path,
    String? name,
    bool clear = false,
  }) => ScheduleEvent(
    id: id,
    title: title,
    subtitle: subtitle,
    time: time,
    eventDate: eventDate,
    daysDescription: daysDescription,
    dayOfWeek: dayOfWeek,
    location: location,
    type: type,
    departmentId: departmentId,
    recurringCycle: recurringCycle,
    icon: icon,
    color: color,
    notes: notes,
    monthlyTheme: monthlyTheme,
    attachmentPath: clear ? null : path ?? attachmentPath,
    attachmentName: clear ? null : name ?? attachmentName,
    linkText: linkText,
    linkUrl: linkUrl,
  );

  static int compareByTime(ScheduleEvent first, ScheduleEvent second) {
    final firstMinutes = _minutesSinceMidnight(first.time);
    final secondMinutes = _minutesSinceMidnight(second.time);
    if (firstMinutes != secondMinutes) {
      return firstMinutes.compareTo(secondMinutes);
    }
    return first.title.compareTo(second.title);
  }

  static int _minutesSinceMidnight(String value) {
    final match = RegExp(r'^\s*(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return 24 * 60;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return 24 * 60;
    }
    return hour * 60 + minute;
  }

  /// Converte uma linha de `eventos_agenda` para o modelo do app.
  factory ScheduleEvent.fromDatabase(Map<String, dynamic> row) {
    final tipoSalvo = row['tipo'] as String?;
    return ScheduleEvent(
      id: row['id'] as String,
      title: row['titulo'] as String,
      subtitle: row['subtitulo'] as String,
      time: row['horario'] as String,
      eventDate: row['data_evento'] == null
          ? null
          : DateTime.tryParse(row['data_evento'].toString()),
      daysDescription: row['descricao_dias'] as String,
      dayOfWeek: row['dia_semana'] as int?,
      location: row['local'] as String,
      type: EventType.values.firstWhere(
        (tipo) => tipo.name == tipoSalvo,
        orElse: () => EventType.culto,
      ),
      departmentId: row['departamento_id'] as String?,
      recurringCycle: row['ciclo_recorrencia'] as String?,
      icon: materialIconFromCode(row['icone']),
      color: Color((row['cor'] as num).toInt()),
      notes: row['observacoes'] as String,
      monthlyTheme: row['tema_mensal'] as bool? ?? false,
      attachmentPath: row['anexo_path'] as String?,
      attachmentName: row['anexo_nome'] as String?,
      linkText: row['link_texto'] as String?,
      linkUrl: row['link_url'] as String?,
    );
  }

  /// Converte o modelo para os nomes de coluna da tabela `eventos_agenda`.
  Map<String, dynamic> toDatabase() => {
    'id': id,
    'titulo': title,
    'subtitulo': subtitle,
    'horario': time,
    'data_evento': eventDate == null
        ? null
        : '${eventDate!.year.toString().padLeft(4, '0')}-${eventDate!.month.toString().padLeft(2, '0')}-${eventDate!.day.toString().padLeft(2, '0')}',
    'descricao_dias': daysDescription,
    'dia_semana': dayOfWeek,
    'local': location,
    'tipo': type.name,
    'departamento_id': departmentId,
    'ciclo_recorrencia': recurringCycle,
    'icone': icon.codePoint,
    'cor': color.toARGB32(),
    'observacoes': notes,
    'tema_mensal': monthlyTheme,
    'anexo_path': attachmentPath,
    'anexo_nome': attachmentName,
    'link_texto': linkText,
    'link_url': linkUrl,
  };

  bool matchesDay(int weekday) {
    if (weekday < DateTime.monday || weekday > DateTime.sunday) return false;
    if (dayOfWeek != null) return dayOfWeek == weekday;

    final description = _normalizeWeekdayText(daysDescription);
    final cycle = _normalizeWeekdayText(recurringCycle ?? '');
    if (cycle.contains('diario') ||
        description.contains('todos os dias') ||
        description.contains('segunda a domingo')) {
      return true;
    }

    const weekdayNames = [
      'segunda',
      'terca',
      'quarta',
      'quinta',
      'sexta',
      'sabado',
      'domingo',
    ];
    final foundDays = <int>[];
    for (var index = 0; index < weekdayNames.length; index++) {
      if (RegExp('\\b${weekdayNames[index]}').hasMatch(description)) {
        foundDays.add(index + 1);
      }
    }
    if (foundDays.isEmpty) return false;

    final range = RegExp(
      r'\b(segunda|terca|quarta|quinta|sexta|sabado|domingo)\s+a\s+'
      r'(segunda|terca|quarta|quinta|sexta|sabado|domingo)\b',
    ).firstMatch(description);
    if (range == null) return foundDays.contains(weekday);
    final start = weekdayNames.indexOf(range.group(1)!) + 1;
    final end = weekdayNames.indexOf(range.group(2)!) + 1;
    if (start <= end) return weekday >= start && weekday <= end;
    return weekday >= start || weekday <= end;
  }

  static String _normalizeWeekdayText(String value) => value
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('â', 'a')
      .replaceAll('é', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('ô', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ç', 'c');
}
