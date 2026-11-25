import 'package:shared_preferences/shared_preferences.dart';

import '../models/announcement.dart';
import '../configuracao_supabase.dart';
import 'content_service.dart';

class MemberNotificationInboxService {
  static String _readIdsKey(String userId) =>
      'avisos_lidos_${Uri.encodeComponent(userId)}';

  static Future<List<Announcement>> announcements(String userId) async {
    final announcements = await ContentService.listAnnouncementsForMember();
    final preferences = await SharedPreferences.getInstance();
    final readIds =
        preferences.getStringList(_readIdsKey(userId))?.toSet() ?? <String>{};
    final legacyAnnouncements = announcements
        .where((announcement) => announcement.isMembersOnly)
        .map(
          (announcement) => announcement.copyWith(
            isRead: announcement.isRead || readIds.contains(announcement.id),
          ),
        )
        .toList();
    if (!supabaseInicializado) return legacyAnnouncements;

    final notifications = await ContentService.listNotifications(userId);
    final result = [...legacyAnnouncements, ...notifications]
      ..sort((first, second) => second.date.compareTo(first.date));
    return result;
  }

  static Future<List<Announcement>> unreadAnnouncements(String userId) async {
    final all = await announcements(userId);
    return all.where((announcement) => !announcement.isRead).toList();
  }

  static Future<void> markRead(String userId, String announcementId) async {
    if (announcementId.startsWith('notificacao_')) {
      await ContentService.markNotificationRead(
        userId: userId,
        notificationId: announcementId.replaceFirst('notificacao_', ''),
      );
      return;
    }
    if (announcementId.startsWith('membro_') && supabaseInicializado) {
      await ContentService.markMemberNoticeViewed(
        announcementId.replaceFirst('membro_', ''),
      );
    }
    final preferences = await SharedPreferences.getInstance();
    final key = _readIdsKey(userId);
    final readIds = preferences.getStringList(key) ?? <String>[];
    if (readIds.contains(announcementId)) return;
    await preferences.setStringList(key, [...readIds, announcementId]);
  }

  static Future<void> markAllRead(
    String userId,
    Iterable<Announcement> announcements,
  ) async {
    final notificationIds = announcements
        .where((announcement) => announcement.notificationId != null)
        .map((announcement) => announcement.notificationId!)
        .toList();
    if (notificationIds.isNotEmpty) {
      await ContentService.markAllNotificationsRead(userId);
    }
    final memberNoticeIds = announcements
        .where(
          (announcement) =>
              announcement.id.startsWith('membro_') && !announcement.isRead,
        )
        .map((announcement) => announcement.id.replaceFirst('membro_', ''))
        .toList();
    if (memberNoticeIds.isNotEmpty && supabaseInicializado) {
      await ContentService.markMemberNoticesViewed(memberNoticeIds);
    }
    final preferences = await SharedPreferences.getInstance();
    final key = _readIdsKey(userId);
    final readIds = preferences.getStringList(key)?.toSet() ?? <String>{};
    readIds.addAll(
      announcements
          .where(
            (announcement) =>
                announcement.isMembersOnly &&
                announcement.notificationId == null &&
                !announcement.isRead,
          )
          .map((announcement) => announcement.id),
    );
    await preferences.setStringList(key, readIds.toList());
  }
}
