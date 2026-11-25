import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/schedule_event.dart';
import '../services/content_service.dart';

class EventAttachmentActions extends StatelessWidget {
  final ScheduleEvent event;

  const EventAttachmentActions({super.key, required this.event});

  Future<void> _downloadAttachment(BuildContext context) async {
    final path = event.attachmentPath;
    if (path == null) return;
    try {
      final url = await ContentService.createEventAttachmentUrl(
        path,
        download: true,
        fileName: event.attachmentName,
      );
      final opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        throw StateError('Não foi possível abrir o link do arquivo.');
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível baixar o material: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (event.attachmentPath == null) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        tooltip: 'Baixar material',
        onPressed: () => _downloadAttachment(context),
        icon: const Icon(Icons.download_rounded),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
