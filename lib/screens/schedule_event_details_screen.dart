import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/schedule_event.dart';
import '../services/auth_service.dart';
import '../services/content_service.dart';
import '../utils/youtube_video_url.dart';
import '../widgets/app_navigation_actions.dart';
import '../widgets/event_attachment_actions.dart';
import '../widgets/event_attachment_preview.dart';
import '../widgets/event_youtube_player.dart';

class ScheduleEventDetailsScreen extends StatelessWidget {
  final ScheduleEvent event;
  final DateTime? selectedDate;
  final AuthService authService;

  const ScheduleEventDetailsScreen({
    super.key,
    required this.event,
    required this.authService,
    this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (!authService.hasApprovedMemberAccess) {
      final isPending = authService.isAwaitingApproval;
      return Scaffold(
        appBar: AppBar(
          leading: AppNavigationMenuButton(
            tooltip: 'Voltar à agenda',
            onPressed: () => Navigator.of(context).maybePop(),
            showBackButton: true,
            user: authService.isAuthenticated ? authService.currentUser : null,
          ),
          title: const Text('Acesso à agenda'),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.lock_outline_rounded,
                        color: const Color(0xFF0F766E),
                        size: 46,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isPending
                            ? 'Aguardando aprovação'
                            : 'Informações restritas',
                        style: Theme.of(context).textTheme.titleLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isPending
                            ? 'Seu acesso básico está liberado. Os detalhes e arquivos desta agenda estarão disponíveis após a aprovação da administração.'
                            : 'Os detalhes e arquivos da agenda são liberados para membros após aprovação da administração. Entre em contato com a secretaria para solicitar acesso.',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final date = selectedDate ?? event.eventDate;
    final youtubeVideoId = youtubeVideoIdFromUrl(event.linkUrl);
    final dateText = date == null
        ? event.daysDescription
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';
    final eventInformationCard = Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: event.color.withAlpha(28),
                  child: Icon(event.icon, color: event.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.subtitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DetailRow(
              icon: Icons.calendar_month_outlined,
              label: 'Data',
              value: dateText,
            ),
            _DetailRow(
              icon: Icons.schedule_outlined,
              label: 'Horário',
              value: event.time,
            ),
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Local',
              value: event.location,
            ),
            if (event.recurringCycle?.isNotEmpty == true)
              _DetailRow(
                icon: Icons.repeat_rounded,
                label: 'Repetição',
                value: event.recurringCycle!,
              ),
          ],
        ),
      ),
    );
    final informationCards = <Widget>[
      if (event.notes.trim().isNotEmpty)
        _DetailsCard(
          title: 'Informações',
          child: Text(event.notes, style: const TextStyle(height: 1.5)),
        ),
    ];
    final resourceCards = <Widget>[
      if (event.linkUrl?.isNotEmpty == true)
        _DetailsCard(
          title: youtubeVideoId == null ? 'Link do evento' : 'Vídeo do evento',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (youtubeVideoId != null) ...[
                EventYoutubePlayer(videoId: youtubeVideoId),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => _openEventLink(context),
                  child: Row(
                    children: [
                      const Icon(Icons.open_in_new_rounded),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          event.linkText?.trim().isNotEmpty == true
                              ? event.linkText!
                              : event.linkUrl!,
                          textAlign: TextAlign.left,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      if (event.attachmentPath != null)
        _DetailsCard(
          title: 'Material anexado',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (authService.hasApprovedMemberAccess)
                EventAttachmentPreview(
                  event: event,
                  loadUrl: () => ContentService.createEventAttachmentUrl(
                    event.attachmentPath!,
                  ),
                ),
              if (authService.hasApprovedMemberAccess) ...[
                const SizedBox(height: 12),
                EventAttachmentActions(event: event),
              ] else
                Text(
                  authService.isAwaitingApproval
                      ? 'Seu cadastro está aguardando autorização da administração para abrir o material.'
                      : !authService.isAuthenticated
                      ? 'Entre na sua conta de membro para abrir o material.'
                      : 'Os materiais da agenda são liberados para membros após aprovação da administração.',
                ),
            ],
          ),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        leading: AppNavigationMenuButton(
          tooltip: 'Voltar à agenda',
          onPressed: () => Navigator.of(context).maybePop(),
          showBackButton: true,
          user: authService.isAuthenticated ? authService.currentUser : null,
        ),
        title: Text(event.title),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 800;
          final useTwoColumns = wide && resourceCards.isNotEmpty;
          final content = useTwoColumns
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _DetailsColumn(
                        cards: [eventInformationCard, ...informationCards],
                        spacing: 16,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      flex: 7,
                      child: _DetailsColumn(cards: resourceCards, spacing: 16),
                    ),
                  ],
                )
              : _DetailsColumn(
                  cards: [
                    eventInformationCard,
                    ...informationCards,
                    ...resourceCards,
                  ],
                  spacing: 12,
                );

          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: useTwoColumns ? 1440 : 960),
              child: ListView(
                padding: EdgeInsets.all(wide ? 24 : 16),
                children: [content],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openEventLink(BuildContext context) async {
    final uri = Uri.tryParse(event.linkUrl?.trim() ?? '');
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('O link deste evento é inválido.')),
      );
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o link.')),
      );
    }
  }
}

class _DetailsColumn extends StatelessWidget {
  final List<Widget> cards;
  final double spacing;

  const _DetailsColumn({required this.cards, required this.spacing});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var index = 0; index < cards.length; index++) ...[
        if (index > 0) SizedBox(height: spacing),
        cards[index],
      ],
    ],
  );
}

class _DetailsCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _DetailsCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          child,
        ],
      ),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF0F766E)),
        const SizedBox(width: 10),
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
