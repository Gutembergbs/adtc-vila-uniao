import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/schedule_event.dart';
import '../services/auth_service.dart';
import '../services/agenda_notification_service.dart';
import '../services/content_service.dart';
import '../widgets/app_navigation_actions.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final AuthService authService;

  const NotificationSettingsScreen({super.key, required this.authService});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  List<ScheduleEvent> _events = [];
  bool _remindersEnabled = false;
  bool _changesEnabled = false;
  int _minutesBefore = 30;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        AgendaNotificationService.carregarPreferencias(),
        ContentService.listScheduleEvents(),
      ]);
      final preferences = results[0] as AgendaNotificationPreferences;
      final events = results[1] as List<ScheduleEvent>;
      if (!mounted) return;
      setState(() {
        _events = events;
        _remindersEnabled = preferences.lembretesAtivos;
        _changesEnabled = preferences.avisarMudancas;
        _minutesBefore = preferences.minutosAntes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Não foi possível carregar as preferências: $error';
      });
    }
  }

  Future<void> _saveSettings() async {
    final webPushRequested = kIsWeb && (_changesEnabled || _remindersEnabled);
    if (webPushRequested && !widget.authService.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.authService.isAwaitingApproval
                ? 'Seu cadastro está aguardando autorização da administração para ativar notificações no navegador.'
                : 'Entre na conta de membro para ativar notificações no navegador.',
          ),
        ),
      );
      return;
    }
    if (webPushRequested &&
        !AgendaNotificationService.pushFirebaseConfigurado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Configure o app Firebase para Web e a chave VAPID antes de ativar as notificações.',
          ),
        ),
      );
      return;
    }

    final requestedChangesEnabled = _changesEnabled;
    setState(() => _saving = true);
    try {
      final permissionGranted =
          await AgendaNotificationService.salvarPreferencias(
            lembretesAtivos: _remindersEnabled,
            avisarMudancas: _changesEnabled,
            minutosAntes: _minutesBefore,
            eventos: _events,
          );
      if (!mounted) return;
      if (!permissionGranted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AgendaNotificationService.lastPushRegistrationError ??
                  (kIsWeb
                      ? 'Permita as notificações no navegador e tente novamente.'
                      : 'Permita as notificações nas configurações do aparelho e tente novamente.'),
            ),
          ),
        );
        return;
      }

      final savedPreferences =
          await AgendaNotificationService.carregarPreferencias();
      if (!mounted) return;
      setState(() {
        _changesEnabled = savedPreferences.avisarMudancas;
        _remindersEnabled = savedPreferences.lembretesAtivos;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preferências de notificação salvas.')),
      );
      if (requestedChangesEnabled &&
          !AgendaNotificationService.pushFirebaseConfigurado) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Avisos remotos não ativados: o Firebase ainda não está configurado neste app.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        if (kIsWeb) {
          _changesEnabled = false;
          _remindersEnabled = false;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível salvar: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.of(context).maybePop(),
          showBackButton: true,
          user: widget.authService.isAuthenticated
              ? widget.authService.currentUser
              : null,
        ),
        title: const Text('Notificações'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadSettings,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tentar novamente'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  color: Color(0xFFEFF6FF),
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Ative as notificações do dispositivo para receber '
                      'avisos importantes da igreja, atualizações da agenda '
                      'e novos comunicados. Escolha uma das opções abaixo; '
                      'o app solicitará a permissão do aparelho.',
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (widget.authService.isAwaitingApproval) ...[
                  const Card(
                    color: Color(0xFFFFF7E6),
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Seu cadastro está aguardando autorização da administração. Você poderá ativar avisos no navegador depois que o acesso for aprovado.',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.notifications_active_outlined,
                          color: Color(0xFF0F766E),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Escolha os avisos que deseja receber',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Ao ativar uma opção, o app solicitará a permissão de notificações deste aparelho.',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (kIsWeb)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No navegador, os lembretes dos eventos podem chegar mesmo com o app fechado. Isso requer notificações permitidas e o agendamento push configurado no servidor.',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Lembretes dos eventos'),
                        subtitle: const Text(
                          'Receba um aviso antes do início dos eventos da agenda. Na Web, o envio depende do agendamento push do servidor.',
                        ),
                        value: _remindersEnabled,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _remindersEnabled = value),
                      ),
                      if (_remindersEnabled)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          child: DropdownButtonFormField<int>(
                            initialValue: _minutesBefore,
                            decoration: const InputDecoration(
                              labelText: 'Antecedência do lembrete',
                            ),
                            items: const [10, 15, 30, 60]
                                .map(
                                  (minutes) => DropdownMenuItem(
                                    value: minutes,
                                    child: Text('$minutes minutos'),
                                  ),
                                )
                                .toList(),
                            onChanged: _saving
                                ? null
                                : (value) {
                                    if (value != null) {
                                      setState(() => _minutesBefore = value);
                                    }
                                  },
                          ),
                        ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Avisos de mudanças na programação'),
                        subtitle: const Text(
                          'Receba avisos quando eventos da agenda forem alterados.',
                        ),
                        value: _changesEnabled,
                        onChanged: _saving
                            ? null
                            : (value) =>
                                  setState(() => _changesEnabled = value),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!AgendaNotificationService.pushFirebaseConfigurado)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Avisos remotos exigem a configuração do Firebase no app e no servidor. Para Web, também configure o app Firebase para navegador e a chave VAPID.',
                        style: TextStyle(color: Color(0xFF78350F)),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _saving ? null : _saveSettings,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Salvando...' : 'Salvar preferências'),
                ),
              ],
            ),
    );
  }
}
