import 'package:flutter/material.dart';

import 'member_avatar.dart';
import '../services/auth_service.dart';
import '../services/data_service.dart';

class CustomDrawer extends StatelessWidget {
  final AuthService authService;
  final Function(int) onSelectTab;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenAdmin;
  final VoidCallback onOpenNotificationSettings;

  const CustomDrawer({
    super.key,
    required this.authService,
    required this.onSelectTab,
    required this.onOpenAbout,
    required this.onOpenAdmin,
    required this.onOpenNotificationSettings,
  });

  @override
  Widget build(BuildContext context) {
    final user = authService.currentUser;
    final isAuth = authService.isAuthenticated;

    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A2540), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset(
                        'assets/church_logo.png',
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ADTC Vila União',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: Color(0xFFF59E0B),
                                size: 13,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                DataService.churchCity,
                                style: TextStyle(
                                  color: Colors.white.withAlpha(210),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: isAuth
                        ? () {
                            Navigator.pop(context);
                            onSelectTab(4);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(25),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withAlpha(40)),
                      ),
                      child: Row(
                        children: [
                          if (user != null)
                            MemberAvatar(user: user, radius: 18)
                          else
                            const CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xFFF59E0B),
                              child: Text(
                                'V',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user?.displayName ?? 'Visitante',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  !isAuth
                                      ? 'Modo visitante • Acesso básico'
                                      : user?.isVisitor == true
                                      ? 'Visitante • Acesso básico'
                                      : authService.isAwaitingApproval
                                      ? 'Aguardando aprovação'
                                      : (user?.department ?? 'Membro ativo'),
                                  style: TextStyle(
                                    color: Colors.white.withAlpha(190),
                                    fontSize: 11,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (isAuth)
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFD5F5EF),
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.home_rounded,
                    color: Color(0xFF0A2540),
                  ),
                  title: const Text('Início'),
                  onTap: () {
                    Navigator.pop(context);
                    onSelectTab(0);
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF0F766E),
                  ),
                  title: const Text('Notificações'),
                  subtitle: const Text(
                    'Ativar avisos e permissões do app',
                    style: TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenNotificationSettings();
                  },
                ),
                if (user?.isAdmin == true)
                  ListTile(
                    leading: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Color(0xFF0F766E),
                    ),
                    title: const Text('Área administrativa'),
                    subtitle: const Text(
                      'Gerenciar agenda e departamentos',
                      style: TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      onOpenAdmin();
                    },
                  ),
                ListTile(
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blueGrey,
                  ),
                  title: const Text('Sobre a Congregação'),
                  onTap: () {
                    Navigator.pop(context);
                    onOpenAbout();
                  },
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'ADTC Vila União - Sobral',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        isAuth
                            ? 'Logado: ${user?.name}'
                            : 'Modo Visitante Ativo',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isAuth)
                  IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.red),
                    tooltip: 'Sair da conta',
                    onPressed: () {
                      authService.logout();
                      Navigator.pop(context);
                    },
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.login_rounded, size: 16),
                    label: const Text('Entrar'),
                    onPressed: () {
                      Navigator.pop(context);
                      onSelectTab(4);
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
