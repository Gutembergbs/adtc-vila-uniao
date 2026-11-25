import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/utils/youtube_video_url.dart';

void main() {
  group('youtubeVideoIdFromUrl', () {
    test('parses standard, short, shorts, and embed links', () {
      expect(
        youtubeVideoIdFromUrl(
          'https://www.youtube.com/watch?v=AbCdEf_1234&t=30',
        ),
        'AbCdEf_1234',
      );
      expect(
        youtubeVideoIdFromUrl('https://youtu.be/AbCdEf_1234?si=share'),
        'AbCdEf_1234',
      );
      expect(
        youtubeVideoIdFromUrl('https://m.youtube.com/shorts/AbCdEf_1234'),
        'AbCdEf_1234',
      );
      expect(
        youtubeVideoIdFromUrl(
          'https://www.youtube-nocookie.com/embed/AbCdEf_1234',
        ),
        'AbCdEf_1234',
      );
    });

    test('rejects non-YouTube hosts and URLs without a video ID', () {
      expect(
        youtubeVideoIdFromUrl(
          'https://youtube.com.example.org/watch?v=AbCdEf_1234',
        ),
        isNull,
      );
      expect(
        youtubeVideoIdFromUrl('https://www.youtube.com/playlist?list=x'),
        isNull,
      );
      expect(
        youtubeVideoIdFromUrl('https://www.youtube.com/watch?v=too-short'),
        isNull,
      );
    });
  });
}
