import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:adtc_vila_uniao/services/bible_api_service.dart';

void main() {
  test('loads Portuguese books and complete chapters', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/por_bsl/books.json') {
        return http.Response(
          jsonEncode({
            'books': List.generate(
              81,
              (index) => {
                'id': index == 0 ? 'GEN' : 'BOOK$index',
                'name': index == 0 ? 'Gênesis' : 'Livro $index',
                'commonName': index == 0 ? 'Gênesis' : 'Livro $index',
                'shortName': index == 0 ? 'Gn' : '',
                'numberOfChapters': index == 0 ? 2 : 1,
                if (index >= 66) 'isApocryphal': true,
              },
            ),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      if (request.url.path == '/api/por_bsl/GEN/1.json') {
        return http.Response(
          jsonEncode({
            'book': {'name': 'Gênesis'},
            'chapter': {
              'number': 1,
              'content': [
                {'type': 'line_break'},
                {
                  'type': 'verse',
                  'number': 1,
                  'content': [
                    ' No princípio',
                    {'noteId': 0},
                    ' criou Deus. ',
                  ],
                },
                {
                  'type': 'verse',
                  'number': 2,
                  'content': ['A terra era sem forma e vazia.'],
                },
              ],
            },
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not found', 404);
    });
    final service = BibleApiService(client: client);
    addTearDown(service.dispose);

    final books = await service.listBooks();
    expect(books, hasLength(66));
    expect(books.first.name, 'Gênesis');

    final chapters = await service.listChapters(books.first);
    expect(chapters, [1, 2]);

    final chapter = await service.getChapter(books.first, 1);
    expect(chapter.reference, 'Gênesis 1');
    expect(chapter.verses.first.text, 'No princípio criou Deus.');
    expect(chapter.verses.last.text, 'A terra era sem forma e vazia.');
  });

  test(
    'searches accent-insensitive Portuguese book and verse references',
    () async {
      final client = MockClient((request) async {
        if (request.url.path == '/api/por_bsl/books.json') {
          return http.Response(
            jsonEncode({
              'books': List.generate(
                66,
                (index) => {
                  'id': index == 0 ? 'GEN' : 'BOOK$index',
                  'name': index == 0 ? 'Gênesis' : 'Livro $index',
                  'commonName': index == 0 ? 'Gênesis' : 'Livro $index',
                  'shortName': index == 0 ? 'Gn' : '',
                  'numberOfChapters': 1,
                },
              ),
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/por_bsl/GEN/1.json') {
          return http.Response(
            jsonEncode({
              'book': {'name': 'Gênesis'},
              'chapter': {
                'number': 1,
                'content': [
                  {
                    'type': 'verse',
                    'number': 1,
                    'content': ['Versículo um.'],
                  },
                  {
                    'type': 'verse',
                    'number': 2,
                    'content': ['Versículo dois.'],
                  },
                  {
                    'type': 'verse',
                    'number': 3,
                    'content': ['Versículo três.'],
                  },
                ],
              },
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        return http.Response('Not found', 404);
      });
      final service = BibleApiService(client: client);
      addTearDown(service.dispose);

      final passage = await service.searchPassage('Genesis 1:2-3');

      expect(passage.reference, 'Gênesis 1:2-3');
      expect(passage.verses.map((verse) => verse.number), [2, 3]);
    },
  );

  test('rejects invalid chapter references', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/por_bsl/books.json') {
        return http.Response(
          jsonEncode({
            'books': List.generate(
              66,
              (index) => {
                'id': 'BOOK$index',
                'name': 'Livro $index',
                'numberOfChapters': 1,
              },
            ),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }
      return http.Response('Not found', 404);
    });
    final service = BibleApiService(client: client);
    addTearDown(service.dispose);

    await expectLater(
      service.searchPassage('Gênesis referência'),
      throwsA(isA<FormatException>()),
    );
  });

  test('retries temporary API errors before loading books', () async {
    var requests = 0;
    final client = MockClient((request) async {
      requests++;
      if (requests == 1) return http.Response('Temporarily unavailable', 503);
      return http.Response(
        jsonEncode({
          'books': List.generate(
            66,
            (index) => {
              'id': 'BOOK$index',
              'name': 'Livro $index',
              'numberOfChapters': 1,
            },
          ),
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final service = BibleApiService(client: client);
    addTearDown(service.dispose);

    final books = await service.listBooks();

    expect(books, hasLength(66));
    expect(requests, 2);
  });
}
