import 'package:flutter/material.dart';
import '../utils/material_icon_data.dart';

class Department {
  final String id;
  final String name;
  final int order;
  final String? conjuntoName;
  final String? conjuntoHistory;
  final String description;
  final List<String> responsibilities;
  final String leaderName;
  final String meetingSchedule;
  final IconData icon;
  final Color color;
  final List<String> tags;
  final String? instagram;

  const Department({
    required this.id,
    required this.name,
    this.order = 0,
    this.conjuntoName,
    this.conjuntoHistory,
    required this.description,
    required this.responsibilities,
    required this.leaderName,
    required this.meetingSchedule,
    required this.icon,
    required this.color,
    required this.tags,
    this.instagram,
  });

  /// Converte uma linha de `departamentos` para o modelo usado pelas telas.
  factory Department.fromDatabase(Map<String, dynamic> row) {
    return Department(
      id: row['id'] as String,
      name: row['nome'] as String,
      order: row['ordem'] as int? ?? 0,
      conjuntoName: row['nome_conjunto'] as String?,
      conjuntoHistory: row['historico_conjunto'] as String?,
      description: row['descricao'] as String,
      responsibilities: List<String>.from(row['responsabilidades'] as List),
      leaderName: row['responsavel'] as String,
      meetingSchedule: row['horario_reuniao'] as String,
      icon: materialIconFromCode(row['icone']),
      color: Color((row['cor'] as num).toInt()),
      tags: List<String>.from(row['tags'] as List),
      instagram: row['instagram'] as String?,
    );
  }

  Department copyWith({int? order}) => Department(
    id: id,
    name: name,
    order: order ?? this.order,
    conjuntoName: conjuntoName,
    conjuntoHistory: conjuntoHistory,
    description: description,
    responsibilities: responsibilities,
    leaderName: leaderName,
    meetingSchedule: meetingSchedule,
    icon: icon,
    color: color,
    tags: tags,
    instagram: instagram,
  );

  /// Converte o modelo para os nomes de coluna da tabela `departamentos`.
  Map<String, dynamic> toDatabase() => {
    'id': id,
    'nome': name,
    'ordem': order,
    'nome_conjunto': conjuntoName,
    'historico_conjunto': conjuntoHistory,
    'descricao': description,
    'responsabilidades': responsibilities,
    'responsavel': leaderName,
    'horario_reuniao': meetingSchedule,
    'icone': icon.codePoint,
    'cor': color.toARGB32(),
    'tags': tags,
    'instagram': instagram,
  };

  String get displayName =>
      conjuntoName != null ? '$name ($conjuntoName)' : name;
}
