import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

const _bibleTranslationId = 'por_bsl';
const _bibleApiHost = 'bible.helloao.org';

class BibleBook {
  final String id;
  final String name;
  final String shortName;
  final int chapterCount;

  const BibleBook({
    required this.id,
    required this.name,
    required this.shortName,
    required this.chapterCount,
  });

  factory BibleBook.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString();
    final name = (json['commonName'] ?? json['name'])?.toString();
    final shortName = json['shortName']?.toString() ?? '';
    final rawChapterCount = json['numberOfChapters'];
    final chapterCount = rawChapterCount is num
        ? rawChapterCount.toInt()
        : int.tryParse(rawChapterCount?.toString() ?? '');
    if (id == null ||
        id.isEmpty ||
        name == null ||
        name.isEmpty ||
        chapterCount == null ||
        chapterCount < 1) {
      throw const FormatException('Livro bíblico sem dados válidos.');
    }
    return BibleBook(
      id: id,
      name: name,
      shortName: shortName,
      chapterCount: chapterCount,
    );
  }
}

class BibleVerse {
  final int number;
  final String text;

  const BibleVerse({required this.number, required this.text});

  factory BibleVerse.fromJson(Map<String, dynamic> json) {
    final rawNumber = json['number'] ?? json['verse'];
    final number = rawNumber is num
        ? rawNumber.toInt()
        : int.tryParse(rawNumber?.toString() ?? '');
    final text = json['text']?.toString() ?? _plainText(json['content']).trim();
    if (number == null || number < 1 || text.isEmpty) {
      throw const FormatException('Versículo sem número ou texto.');
    }
    return BibleVerse(number: number, text: text);
  }
}

class BibleChapter {
  final String reference;
  final String bookName;
  final int chapter;
  final List<BibleVerse> verses;

  const BibleChapter({
    required this.reference,
    required this.bookName,
    required this.chapter,
    required this.verses,
  });

  factory BibleChapter.fromJson(
    Map<String, dynamic> json, {
    required String fallbackBookName,
    required int fallbackChapter,
  }) {
    final rawBook = json['book'];
    final bookName = rawBook is Map
        ? (rawBook['commonName'] ?? rawBook['name'])?.toString() ??
              fallbackBookName
        : rawBook?.toString() ?? fallbackBookName;
    final rawChapter = json['chapter'];
    final chapterValue = rawChapter is Map
        ? rawChapter['number']
        : rawChapter;
    final chapter = chapterValue is num
        ? chapterValue.toInt()
        : int.tryParse(chapterValue?.toString() ?? '') ?? fallbackChapter;
    final rawVerses = rawChapter is Map
        ? rawChapter['content']
        : json['verses'];
    if (rawVerses is! List) {
      throw const FormatException(
        'A API não retornou os versículos do capítulo.',
      );
    }
    final verses = rawVerses
        .whereType<Map>()
        .where((verse) => verse['type'] == null || verse['type'] == 'verse')
        .map(
          (verse) => BibleVerse.fromJson(Map<String, dynamic>.from(verse)),
        )
        .toList();
    if (verses.isEmpty) {
      throw const FormatException('O capítulo não contém versículos.');
    }
    return BibleChapter(
      reference: '$bookName $chapter',
      bookName: bookName,
      chapter: chapter,
      verses: verses,
    );
  }
}

class BibleApiService {
  BibleApiService({http.Client? client}) : _client = client ?? http.Client();

  static final Uri _booksUri = Uri.https(
    _bibleApiHost,
    '/api/$_bibleTranslationId/books.json',
  );

  final http.Client _client;
  final Map<String, BibleChapter> _chapterContentCache = {};
  List<BibleBook>? _booksCache;

  Future<List<BibleBook>> listBooks() async {
    final cached = _booksCache;
    if (cached != null) return cached;

    final json = await _getJson(_booksUri);
    final rawBooks = json['books'];
    if (rawBooks is! List) {
      throw const FormatException('A API não retornou os livros da Bíblia.');
    }
    final books = rawBooks
        .whereType<Map>()
        .where((book) => book['isApocryphal'] != true)
        .map((book) => BibleBook.fromJson(Map<String, dynamic>.from(book)))
        .toList();
    if (books.length != 66) {
      throw const FormatException('A API não retornou os 66 livros da Bíblia.');
    }
    _booksCache = books;
    return books;
  }

  Future<List<int>> listChapters(BibleBook book) async =>
      List<int>.generate(book.chapterCount, (index) => index + 1);

  Future<BibleChapter> getChapter(BibleBook book, int chapter) async {
    if (chapter < 1 || chapter > book.chapterCount) {
      throw ArgumentError.value(chapter, 'chapter', 'Capítulo inválido.');
    }
    final cacheKey = '${book.id}:$chapter';
    final cached = _chapterContentCache[cacheKey];
    if (cached != null) return cached;

    final json = await _getJson(
      Uri.https(
        _bibleApiHost,
        '/api/$_bibleTranslationId/${book.id}/$chapter.json',
      ),
    );
    final content = BibleChapter.fromJson(
      json,
      fallbackBookName: book.name,
      fallbackChapter: chapter,
    );
    _chapterContentCache[cacheKey] = content;
    return content;
  }

  Future<BibleChapter> searchPassage(String reference) async {
    final normalizedReference = _normalizeReference(reference);
    if (normalizedReference.isEmpty) {
      throw const FormatException('Digite uma referência bíblica.');
    }

    final books = await listBooks();
    final matchingBook = _findBook(normalizedReference, books);
    if (matchingBook == null) {
      throw const FormatException('Livro bíblico não encontrado.');
    }
    final suffix = normalizedReference.substring(matchingBook.key.length).trim();
    final match = RegExp(r'^(\d+)(?::(\d+)(?:\s*-\s*(\d+))?)?$')
        .firstMatch(suffix);
    if (match == null) {
      throw const FormatException(
        'Use uma referência como João 3:16 ou Salmos 23.',
      );
    }

    final chapterNumber = int.parse(match.group(1)!);
    final firstVerse = int.tryParse(match.group(2) ?? '');
    final parsedLastVerse = int.tryParse(match.group(3) ?? '');
    final chapter = await getChapter(matchingBook.value, chapterNumber);
    if (firstVerse == null) return chapter;

    final lastVerse = parsedLastVerse ?? firstVerse;
    if (lastVerse < firstVerse) {
      throw const FormatException('O intervalo de versículos é inválido.');
    }
    final verses = chapter.verses
        .where(
          (verse) => verse.number >= firstVerse && verse.number <= lastVerse,
        )
        .toList();
    if (verses.length != lastVerse - firstVerse + 1) {
      throw const FormatException('A referência não contém todos os versículos.');
    }
    final verseRange = firstVerse == lastVerse
        ? '$firstVerse'
        : '$firstVerse-$lastVerse';
    return BibleChapter(
      reference: '${matchingBook.value.name} $chapterNumber:$verseRange',
      bookName: matchingBook.value.name,
      chapter: chapterNumber,
      verses: verses,
    );
  }

  MapEntry<String, BibleBook>? _findBook(
    String reference,
    List<BibleBook> books,
  ) {
    final aliases = <MapEntry<String, BibleBook>>[];
    for (final book in books) {
      for (final name in [book.name, book.shortName]) {
        final alias = _normalizeReference(name);
        if (alias.isNotEmpty) aliases.add(MapEntry(alias, book));
      }
    }
    aliases.sort((first, second) => second.key.length.compareTo(first.key.length));
    for (final alias in aliases) {
      if (reference.startsWith('${alias.key} ')) return alias;
    }
    return null;
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      late http.Response response;
      try {
        response = await _client
            .get(uri, headers: const {'Accept': 'application/json'})
            .timeout(const Duration(seconds: 25));
      } on TimeoutException {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      } on http.ClientException {
        if (attempt == 2) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 500));
        continue;
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final canRetry =
            response.statusCode == 408 ||
            response.statusCode == 429 ||
            response.statusCode >= 500;
        if (canRetry && attempt < 2) {
          await Future<void>.delayed(const Duration(milliseconds: 500));
          continue;
        }
        throw Exception('API bíblica respondeu HTTP ${response.statusCode}.');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida da API bíblica.');
      }
      return decoded;
    }
    throw StateError('Não foi possível carregar os dados da Bíblia.');
  }

  void dispose() => _client.close();
}

String _normalizeReference(String value) => value
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('à', 'a')
    .replaceAll('â', 'a')
    .replaceAll('ã', 'a')
    .replaceAll('ä', 'a')
    .replaceAll('é', 'e')
    .replaceAll('è', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('ë', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ì', 'i')
    .replaceAll('î', 'i')
    .replaceAll('ï', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ò', 'o')
    .replaceAll('ô', 'o')
    .replaceAll('õ', 'o')
    .replaceAll('ö', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ù', 'u')
    .replaceAll('û', 'u')
    .replaceAll('ü', 'u')
    .replaceAll('ç', 'c')
    .replaceAll('.', '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

String _plainText(dynamic content) {
  if (content is String) return content;
  if (content is List) {
    return content.map(_plainText).join();
  }
  if (content is Map) {
    return _plainText(content['content'] ?? content['text']);
  }
  return '';
}
