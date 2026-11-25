import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:adtc_vila_uniao/models/announcement.dart';
import 'package:adtc_vila_uniao/services/member_notification_inbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('marks member announcements as read for the signed-in user', () async {
    const userId = 'member-1';
    final unread = await MemberNotificationInboxService.unreadAnnouncements(
      userId,
    );
    expect(unread, isNotEmpty);

    await MemberNotificationInboxService.markRead(userId, unread.first.id);

    final remaining = await MemberNotificationInboxService.unreadAnnouncements(
      userId,
    );
    expect(remaining.map((item) => item.id), isNot(contains(unread.first.id)));
  });

  test('read state is isolated between member accounts', () async {
    final firstUser = await MemberNotificationInboxService.unreadAnnouncements(
      'member-1',
    );
    await MemberNotificationInboxService.markAllRead('member-1', firstUser);

    expect(
      await MemberNotificationInboxService.unreadAnnouncements('member-1'),
      isEmpty,
    );
    expect(
      await MemberNotificationInboxService.unreadAnnouncements('member-2'),
      isNotEmpty,
    );
  });

  test('lists both read and unread member announcements', () async {
    const userId = 'member-1';
    final unread = await MemberNotificationInboxService.unreadAnnouncements(
      userId,
    );
    final readAnnouncement = unread.first;

    await MemberNotificationInboxService.markRead(userId, readAnnouncement.id);

    final all = await MemberNotificationInboxService.announcements(userId);
    final restored = all.firstWhere((item) => item.id == readAnnouncement.id);

    expect(restored.isRead, isTrue);
    expect(
      (await MemberNotificationInboxService.unreadAnnouncements(
        userId,
      )).map((item) => item.id),
      isNot(contains(readAnnouncement.id)),
    );
  });

  test('inbox notification keeps its agenda event link', () {
    final notification = Announcement.fromNotificationDatabase({
      'id': 'notification-1',
      'titulo': 'Culto especial',
      'resumo': 'Hoje às 19h',
      'conteudo': 'Esperamos você.',
      'categoria': 'Agenda',
      'criado_em': '2026-11-17T12:00:00Z',
      'evento_id': 'event-1',
      'enviado_em': '2026-11-17T12:00:00Z',
    });

    expect(notification.eventId, 'event-1');
    expect(notification.notificationId, 'notification-1');
    expect(notification.id, 'notificacao_notification-1');
    expect(notification.notificationSent, isTrue);
  });

  test('member notice restores its persisted read state', () {
    final announcement = Announcement.fromMemberNoticeDatabase({
      'id': 'notice-1',
      'titulo': 'Aviso',
      'resumo': '',
      'conteudo': 'Conteúdo',
      'categoria': 'Geral',
      'criado_em': '2026-11-17T12:00:00Z',
      'visualizado_em': '2026-11-17T12:05:00Z',
    });

    expect(announcement.isRead, isTrue);
  });
}
