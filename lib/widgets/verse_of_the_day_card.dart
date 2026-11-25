import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/bible_api_service.dart';
import '../services/church_share_service.dart';

class VerseOfTheDayCard extends StatefulWidget {
  const VerseOfTheDayCard({super.key});

  @override
  State<VerseOfTheDayCard> createState() => _VerseOfTheDayCardState();
}

class _VerseOfTheDayCardState extends State<VerseOfTheDayCard> {
  final BibleApiService _bibleApi = BibleApiService();
  BibleChapter? _chapter;
  Object? _error;
  bool _loading = true;
  int _selectedOffset = 0;
  late final DateTime _today;
  late final int _dayIndex;
  late final String _preferenceKey;

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _dayIndex = _today.difference(DateTime(_today.year)).inDays;
    _preferenceKey = 'versiculo_do_dia_${_today.year}_$_dayIndex';
    _loadVerse();
  }

  @override
  void dispose() {
    _bibleApi.dispose();
    super.dispose();
  }

  Future<void> _loadVerse({bool next = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      if (next) {
        _selectedOffset = (_selectedOffset + 1) % 366;
        await preferences.setInt(_preferenceKey, _selectedOffset);
      } else {
        _selectedOffset = preferences.getInt(_preferenceKey) ?? 0;
      }
      final reference = dailyVerseReference(_dayIndex + _selectedOffset);
      final chapter = await _bibleApi.searchPassage(reference);
      if (!mounted) return;
      setState(() {
        _chapter = chapter;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verse = _chapter?.verses.firstOrNull;
    final reference = _chapter?.reference ?? '';
    final verseText = verse?.text ?? '';

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.amber.shade200.withAlpha(120)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.format_quote_rounded,
                    color: Color(0xFFD97706),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Versículo do Dia',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Outro versículo',
                  icon: const Icon(Icons.autorenew_rounded, size: 21),
                  onPressed: _loading ? null : () => _loadVerse(next: true),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 20),
                  tooltip: 'Compartilhar versículo',
                  color: Colors.grey.shade700,
                  onPressed: verse == null
                      ? null
                      : () => ChurchShareService.chooseShareMode(
                          context,
                          title: 'Versículo do Dia',
                          text: '$verseText\n\n$reference',
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Center(child: Text('Carregando versículo...')),
              )
            else if (_error != null)
              Row(
                children: [
                  const Expanded(
                    child: Text('Não foi possível carregar o versículo.'),
                  ),
                  TextButton(
                    onPressed: _loadVerse,
                    child: const Text('Tentar novamente'),
                  ),
                ],
              )
            else ...[
              Text(
                '“$verseText”',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  fontSize: 14.5,
                  height: 1.45,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String dailyVerseReference(int dayIndex) {
  final index = dayIndex % 366;
  final chapter = index % 31 + 1;
  final verse = index ~/ 31 + 1;
  return 'Provérbios $chapter:$verse';
}
