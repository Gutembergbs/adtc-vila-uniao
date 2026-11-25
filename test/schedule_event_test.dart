import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:adtc_vila_uniao/models/schedule_event.dart';
import 'package:adtc_vila_uniao/utils/material_icon_data.dart';
import 'package:adtc_vila_uniao/widgets/event_attachment_actions.dart';
import 'package:adtc_vila_uniao/widgets/event_attachment_preview.dart';

void main() {
  ScheduleEvent event(String id, String time) => ScheduleEvent(
    id: id,
    title: id,
    subtitle: '',
    time: time,
    daysDescription: '',
    location: '',
    type: EventType.culto,
    icon: Icons.church,
    color: const Color(0xFF0F766E),
    notes: '',
  );

  test('serializes a calendar date as a database date', () {
    final event = ScheduleEvent(
      id: 'event-1',
      title: 'Culto especial',
      subtitle: 'Programação da igreja',
      time: '18:30',
      eventDate: DateTime(2026, 10, 26),
      daysDescription: 'Evento único',
      location: 'Templo',
      type: EventType.culto,
      icon: Icons.church,
      color: const Color(0xFF0F766E),
      notes: '',
    );

    expect(event.toDatabase()['data_evento'], '2026-10-26');
  });

  test('serializes optional event attachment metadata', () {
    final event = ScheduleEvent(
      id: 'event-1',
      title: 'Culto especial',
      subtitle: 'Programação da igreja',
      time: '18:30',
      daysDescription: 'Evento único',
      location: 'Templo',
      type: EventType.culto,
      icon: Icons.church,
      color: const Color(0xFF0F766E),
      notes: '',
      linkText: 'Inscreva-se para o retiro',
      linkUrl: 'https://example.com/inscricao',
    ).copyWithAttachment(path: 'event-1/arte.png', name: 'arte.png');

    final row = event.toDatabase();
    final restored = ScheduleEvent.fromDatabase(row);

    expect(row['anexo_path'], 'event-1/arte.png');
    expect(row['anexo_nome'], 'arte.png');
    expect(restored.attachmentPath, 'event-1/arte.png');
    expect(restored.attachmentName, 'arte.png');
    expect(restored.copyWithAttachment(clear: true).attachmentPath, isNull);
    expect(restored.linkText, 'Inscreva-se para o retiro');
    expect(restored.linkUrl, 'https://example.com/inscricao');
  });

  test('sorts events chronologically by time', () {
    final events = [
      event('noite', '19:00'),
      event('tarde', '18:00'),
      event('meio-dia', '12:00'),
    ]..sort(ScheduleEvent.compareByTime);

    expect(events.map((item) => item.id), ['meio-dia', 'tarde', 'noite']);
  });

  test(
    'restores additional department and event icons from database codes',
    () {
      expect(
        materialIconFromCode(Icons.headphones_rounded.codePoint),
        Icons.headphones_rounded,
      );
      expect(
        materialIconFromCode(Icons.event_available_rounded.codePoint),
        Icons.event_available_rounded,
      );
    },
  );

  test(
    'matches only the selected weekday for recurring event descriptions',
    () {
      final doctrine = ScheduleEvent(
        id: 'doutrina',
        title: 'Culto de Doutrina',
        subtitle: '',
        time: '19:00',
        daysDescription: 'Toda Quinta-feira',
        dayOfWeek: null,
        location: '',
        type: EventType.culto,
        icon: Icons.church,
        color: const Color(0xFF0F766E),
        notes: '',
      );
      final dailyPrayer = ScheduleEvent(
        id: 'oracao',
        title: 'Oração do Meio-Dia',
        subtitle: '',
        time: '12:00',
        daysDescription: 'Segunda a Domingo (Todos os dias)',
        recurringCycle: 'Diário',
        location: '',
        type: EventType.oracao,
        icon: Icons.church,
        color: const Color(0xFF0F766E),
        notes: '',
      );

      expect(doctrine.matchesDay(DateTime.thursday), isTrue);
      expect(doctrine.matchesDay(DateTime.sunday), isFalse);
      expect(dailyPrayer.matchesDay(DateTime.thursday), isTrue);
      expect(dailyPrayer.matchesDay(DateTime.sunday), isTrue);
    },
  );

  testWidgets('attachment action only shows a download icon', (
    WidgetTester tester,
  ) async {
    final attachedEvent = event(
      'event-1',
      '18:30',
    ).copyWithAttachment(path: 'event-1/material.pdf', name: 'material.pdf');

    await tester.pumpWidget(
      MaterialApp(home: EventAttachmentActions(event: attachedEvent)),
    );

    expect(find.byTooltip('Baixar material'), findsOneWidget);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
    expect(find.text('Ver material'), findsNothing);
    expect(find.text('Baixar'), findsNothing);
    expect(find.text('material.pdf'), findsNothing);
  });

  testWidgets('missing attachment shows a reupload message', (tester) async {
    final attachedEvent = event(
      'event-1',
      '18:30',
    ).copyWithAttachment(path: 'event-1/arte.png', name: 'arte.png');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventAttachmentPreview(
            event: attachedEvent,
            loadUrl: () async {
              throw StateError(
                'StorageException(statusCode: 404, error: not_found)',
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Este material não está mais disponível. Avise a administração para reenviar o anexo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('image attachment preview uses a 16:9 video-sized frame', (
    tester,
  ) async {
    final attachedEvent = event(
      'event-1',
      '18:30',
    ).copyWithAttachment(path: 'event-1/arte.png', name: 'arte.png');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventAttachmentPreview(
            event: attachedEvent,
            loadUrl: () async => 'https://example.com/arte.png',
          ),
        ),
      ),
    );
    await tester.pump();

    final preview = find.byType(AspectRatio);
    expect(preview, findsOneWidget);
    expect(tester.widget<AspectRatio>(preview).aspectRatio, 16 / 9);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tapping a PDF attachment opens its full preview', (
    tester,
  ) async {
    final attachedEvent = event(
      'event-1',
      '18:30',
    ).copyWithAttachment(path: 'event-1/material.pdf', name: 'material.pdf');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventAttachmentPreview(
            event: attachedEvent,
            loadUrl: () async => 'https://example.com/material.pdf',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tapAt(tester.getCenter(find.byType(AspectRatio)));
    await tester.pumpAndSettle();

    expect(find.text('Visualizar material'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
