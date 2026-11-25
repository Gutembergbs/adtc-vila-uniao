import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import 'member_avatar.dart';
import 'member_notifications_button.dart';

class AppNavigationMenuButton extends StatelessWidget {
  final VoidCallback onPressed;
  final UserProfile? user;
  final String tooltip;
  final bool showBackButton;

  const AppNavigationMenuButton({
    super.key,
    required this.onPressed,
    this.user,
    this.tooltip = '',
    this.showBackButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final member = user;
    final photoUrl = member?.photoUrl;
    return IconButton(
      tooltip: tooltip.isNotEmpty
          ? tooltip
          : (showBackButton ? 'Voltar' : 'Abrir menu do membro'),
      onPressed: onPressed,
      icon: showBackButton
          ? const Icon(Icons.arrow_back_rounded)
          : photoUrl != null && photoUrl.isNotEmpty
          ? MemberAvatar(user: member!, radius: 19)
          : const Icon(Icons.account_circle_outlined),
    );
  }
}

class AppNotificationsAction extends StatelessWidget {
  final AuthService authService;
  final VoidCallback onLoginRequired;

  const AppNotificationsAction({
    super.key,
    required this.authService,
    required this.onLoginRequired,
  });

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    if (authService.isAuthenticated && user != null) {
      return MemberNotificationsButton(userId: user.id);
    }
    return IconButton(
      tooltip: authService.isAwaitingApproval
          ? 'Seu cadastro aguarda autorização para acessar notificações'
          : 'Entre para ver notificações',
      onPressed: onLoginRequired,
      icon: const Icon(Icons.notifications_outlined),
    );
  }
}
