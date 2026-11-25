import 'dart:convert';

import 'package:flutter/services.dart';

class HymnCatalogEntry {
  final int number;
  final String title;

  const HymnCatalogEntry({required this.number, required this.title});

  factory HymnCatalogEntry.fromJson(Map<String, dynamic> json) =>
      HymnCatalogEntry(
        number: json['number'] as int,
        title: json['title'] as String,
      );
}

class HymnCatalogService {
  static Future<List<HymnCatalogEntry>> load() async {
    final source = await rootBundle.loadString('assets/harpa_catalog.json');
    final rows = jsonDecode(source) as List<dynamic>;
    final hymns = rows
        .map(
          (row) =>
              HymnCatalogEntry.fromJson(Map<String, dynamic>.from(row as Map)),
        )
        .toList();
    if (hymns.length != 640) {
      throw FormatException(
        'Catálogo incompleto: esperados 640 títulos, recebidos ${hymns.length}.',
      );
    }
    return hymns;
  }
}
