import 'package:flutter/material.dart';

import '../models/announcement.dart';
import '../services/agenda_notification_service.dart';
import '../services/member_notification_inbox_service.dart';

class MemberNotificationsScreen extends StatefulWidget {
  final String userId;

  const MemberNotificationsScreen({super.key, required this.userId});

  @override
  State<MemberNotificationsScreen> createState() =>
      _MemberNotificationsScreenState();
}

class _MemberNotificationsScreenState extends State<MemberNotificationsScreen> {
  List<Announcement> _announcements = [];
  bool _showRead = false;
  bool _loading = true;
  Object? _error;

  List<Announcement> get _unread =>
      _announcements.where((announcement) => !announcement.isRead).toList();

  List<Announcement> get _visibleAnnouncements => _announcements
      .where((announcement) => announcement.isRead == _showRead)
      .toList();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final announcements = await MemberNotificationInboxService.announcements(
        widget.userId,
      );
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
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

  Future<void> _openAnnouncement(Announcement announcement) async {
    try {
      await MemberNotificationInboxService.markRead(
        widget.userId,
        announcement.id,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível registrar a leitura: $error')),
      );
      return;
    }
    if (!mounted) return;
    setState(() {
      _announcements = _announcements
          .map(
            (item) =>
                item.id == announcement.id ? item.copyWith(isRead: true) : item,
          )
          .toList();
    });
    final eventId = announcement.eventId;
    if (eventId != null) {
      AgendaNotificationService.openEventFromInbox(eventId);
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(announcement.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${announcement.category} • ${announcement.date}',
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 12),
              if (announcement.summary.isNotEmpty) ...[
                Text(
                  announcement.summary,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
              ],
              Text(announcement.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _markAllRead() async {
    try {
      await MemberNotificationInboxService.markAllRead(widget.userId, _unread);
      if (mounted) {
        setState(() {
          _announcements = _announcements
              .map((item) => item.copyWith(isRead: true))
              .toList();
        });
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível marcar como lidas: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificações'),
        actions: [
          if (_unread.isNotEmpty)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Marcar todas como lidas',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text('Não lidas (${_unread.length})'),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(
                    'Lidas (${_announcements.length - _unread.length})',
                  ),
                ),
              ],
              selected: {_showRead},
              onSelectionChanged: (selection) {
                setState(() => _showRead = selection.first);
              },
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Não foi possível carregar os avisos.'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: _load,
                        child: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else if (_visibleAnnouncements.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 32),
                child: Center(child: Text('Não há notificações nesta lista.')),
              )
            else
              ..._visibleAnnouncements.map(
                (announcement) => Card(
                  child: ListTile(
                    leading: announcement.isRead
                        ? const CircleAvatar(
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Icon(
                              Icons.drafts_outlined,
                              color: Color(0xFF475569),
                            ),
                          )
                        : const Badge(
                            smallSize: 9,
                            child: CircleAvatar(
                              backgroundColor: Color(0xFFFFF3D6),
                              child: Icon(
                                Icons.campaign_outlined,
                                color: Color(0xFF9A5B00),
                              ),
                            ),
                          ),
                    title: Text(
                      announcement.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${announcement.category} • ${announcement.date}'
                      '${announcement.isRead ? ' • Lida' : ''}\n'
                      '${announcement.summary}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => _openAnnouncement(announcement),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
