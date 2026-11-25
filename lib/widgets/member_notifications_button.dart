import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../configuracao_supabase.dart';
import '../screens/member_notifications_screen.dart';
import '../services/member_notification_inbox_service.dart';

class MemberNotificationsButton extends StatefulWidget {
  final String userId;

  const MemberNotificationsButton({super.key, required this.userId});

  @override
  State<MemberNotificationsButton> createState() =>
      _MemberNotificationsButtonState();
}

class _MemberNotificationsButtonState extends State<MemberNotificationsButton> {
  int _unreadCount = 0;
  RealtimeChannel? _inboxChannel;

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _subscribeToInbox();
  }

  @override
  void dispose() {
    final channel = _inboxChannel;
    if (channel != null) {
      unawaited(Supabase.instance.client.removeChannel(channel));
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MemberNotificationsButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _refreshCount();
      _subscribeToInbox();
    }
  }

  void _subscribeToInbox() {
    if (!supabaseInicializado) return;
    final currentChannel = _inboxChannel;
    if (currentChannel != null) {
      unawaited(Supabase.instance.client.removeChannel(currentChannel));
    }
    _inboxChannel = Supabase.instance.client
        .channel('member-inbox-${widget.userId}-${identityHashCode(this)}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificacoes_destinatarios',
          callback: (_) => _refreshCount(),
        )
        .subscribe();
  }

  Future<void> _refreshCount() async {
    try {
      final unread = await MemberNotificationInboxService.unreadAnnouncements(
        widget.userId,
      );
      if (mounted) setState(() => _unreadCount = unread.length);
    } catch (error) {
      debugPrint('Não foi possível contar notificações não lidas: $error');
    }
  }

  Future<void> _openInbox() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberNotificationsScreen(userId: widget.userId),
      ),
    );
    await _refreshCount();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Notificações não lidas',
      onPressed: _openInbox,
      icon: Badge(
        isLabelVisible: _unreadCount > 0,
        label: Text(_unreadCount > 99 ? '99+' : '$_unreadCount'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
