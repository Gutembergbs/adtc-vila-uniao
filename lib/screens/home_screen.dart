import 'package:flutter/material.dart';

import '../models/schedule_event.dart';
import '../services/auth_service.dart';
import '../widgets/next_service_card.dart';
import '../widgets/verse_of_the_day_card.dart';
import '../widgets/app_navigation_actions.dart';
import 'tela_pedidos_oracao.dart';
import 'harpa_screen.dart';
import 'contributions_screen.dart';

class HomeScreen extends StatefulWidget {
  final AuthService authService;
  final Function(int) onNavigateTab;
  final VoidCallback onOpenRegistration;
  final ValueChanged<ScheduleEvent> onOpenScheduleEvent;
  final VoidCallback onOpenDrawer;

  const HomeScreen({
    super.key,
    required this.authService,
    required this.onNavigateTab,
    required this.onOpenRegistration,
    required this.onOpenScheduleEvent,
    required this.onOpenDrawer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.authService,
      builder: (context, _) {
        final user = widget.authService.currentUser;
        final isAuth = widget.authService.isAuthenticated;

        return Scaffold(
          appBar: AppBar(
            leading: AppNavigationMenuButton(
              onPressed: widget.onOpenDrawer,
              user: isAuth ? user : null,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'A paz do Senhor,',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(
                  isAuth ? user?.displayName ?? 'membro' : 'visitante!',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            actions: [
              AppNotificationsAction(
                authService: widget.authService,
                onLoginRequired: () => widget.onNavigateTab(4),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NextServiceCard(onOpenEvent: widget.onOpenScheduleEvent),

                    const SizedBox(height: 16),

                    // Quick Actions Grid
                    const Text(
                      'Acesso Rápido',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.calendar_month_rounded,
                            label: 'Agenda',
                            subtitle: 'Semana & Mês',
                            color: const Color(0xFF2563EB),
                            onTap: () => widget.onNavigateTab(1),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.groups_rounded,
                            label: 'Departamentos',
                            subtitle: 'Conjuntos e ministérios',
                            color: const Color(0xFF8B5CF6),
                            onTap: () => widget.onNavigateTab(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.camera_alt_rounded,
                            label: 'Mídia',
                            subtitle: '@adtcvilauniao',
                            color: const Color(0xFF0284C7),
                            onTap: () => widget.onNavigateTab(3),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.volunteer_activism_rounded,
                            label: 'Mural Oração',
                            subtitle: 'Intercessão',
                            color: const Color(0xFFEC4899),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => TelaPedidosOracao(
                                    servicoAutenticacao: widget.authService,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildQuickActionButton(
                            icon: Icons.library_music_rounded,
                            label: 'Harpa Cristã',
                            subtitle: 'Buscar hinos',
                            color: const Color(0xFF7C3AED),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const HarpaScreen(),
                              ),
                            ),
                          ),
                        ),
                        if (widget.authService.hasApprovedMemberAccess) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildQuickActionButton(
                              icon: Icons.volunteer_activism_rounded,
                              label: 'Contribuições',
                              subtitle: 'PIX oficial',
                              color: const Color(0xFF0F766E),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ContributionsScreen(
                                    authService: widget.authService,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    VerseOfTheDayCard(),
                    if (!isAuth) ...[
                      const SizedBox(height: 16),
                      _buildAccountAccessCard(),
                    ],
                    if (isAuth && widget.authService.isAwaitingApproval) ...[
                      const SizedBox(height: 16),
                      Card(
                        color: const Color(0xFFFFF7E6),
                        child: const ListTile(
                          leading: Icon(
                            Icons.hourglass_top_rounded,
                            color: Color(0xFF9A5B00),
                          ),
                          title: Text('Aguardando aprovação'),
                          subtitle: Text(
                            'Você já pode usar o app. O cartão de membro e os detalhes da agenda serão liberados após a análise da administração.',
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAccountAccessCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Acesse sua conta',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const SizedBox(height: 6),
            const Text(
              'Entre ou crie um cadastro para pedir oração e participar do mural.',
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => widget.onNavigateTab(4),
              icon: const Icon(Icons.login_rounded),
              label: const Text('Já tenho cadastro • Entrar'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: widget.onOpenRegistration,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Criar cadastro'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: color.withAlpha(25),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
