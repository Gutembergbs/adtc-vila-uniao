import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/schedule_event.dart';

class EventAttachmentPreview extends StatelessWidget {
  final ScheduleEvent event;
  final Future<String> Function() loadUrl;

  const EventAttachmentPreview({
    super.key,
    required this.event,
    required this.loadUrl,
  });

  bool get _isImage {
    const extensions = ['.jpg', '.jpeg', '.png', '.webp'];
    return [event.attachmentName, event.attachmentPath].whereType<String>().any(
      (value) {
        final name = value.split('?').first.toLowerCase();
        return extensions.any(name.endsWith);
      },
    );
  }

  bool get _isPdf {
    return [event.attachmentName, event.attachmentPath].whereType<String>().any(
      (value) => value.split('?').first.toLowerCase().endsWith('.pdf'),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (event.attachmentPath == null || (!_isImage && !_isPdf)) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<String>(
      future: loadUrl(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          final message =
              error.contains('statusCode: 404') || error.contains('not_found')
              ? 'Este material não está mais disponível. Avise a administração para reenviar o anexo.'
              : 'Prévia indisponível: $error';
          return Text(message);
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            height: 150,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final url = snapshot.data!;
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _isImage
              ? _ImageAttachmentPreview(url: url)
              : _PdfAttachmentPreview(url: url),
        );
      },
    );
  }
}

class _ImageAttachmentPreview extends StatelessWidget {
  final String url;

  const _ImageAttachmentPreview({required this.url});

  @override
  Widget build(BuildContext context) => _TappablePreview(
    label: 'Toque para ampliar',
    onTap: () => Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => _ImageAttachmentViewer(url: url)),
    ),
    child: Image.network(
      url,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) =>
          const _PreviewError(message: 'Não foi possível carregar a imagem.'),
    ),
  );
}

class _PdfAttachmentPreview extends StatelessWidget {
  final String url;

  const _PdfAttachmentPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    final preview = _TappablePreview(
      label: 'Toque para visualizar o PDF',
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => _PdfAttachmentViewer(url: url)),
      ),
      child: IgnorePointer(child: PdfViewer.uri(Uri.parse(url))),
    );

    if (kIsWeb) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          preview,
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _openPdfInBrowser(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Abrir em nova aba'),
            ),
          ),
        ],
      );
    }

    return preview;
  }

  Future<void> _openPdfInBrowser(BuildContext context) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o PDF.')),
      );
    }
  }
}

class _TappablePreview extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Widget child;

  const _TappablePreview({
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: child),
        Material(
          color: Colors.transparent,
          child: InkWell(onTap: onTap, child: const SizedBox.expand()),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: IgnorePointer(
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ImageAttachmentViewer extends StatelessWidget {
  final String url;

  const _ImageAttachmentViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Material anexado')),
    body: Center(
      child: InteractiveViewer(
        minScale: 0.5,
        maxScale: 5,
        child: Image.network(
          url,
          errorBuilder: (context, error, stackTrace) => const _PreviewError(
            message: 'Não foi possível carregar a imagem.',
          ),
        ),
      ),
    ),
  );
}

class _PdfAttachmentViewer extends StatelessWidget {
  final String url;

  const _PdfAttachmentViewer({required this.url});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Visualizar material')),
    body: PdfViewer.uri(Uri.parse(url)),
  );
}

class _PreviewError extends StatelessWidget {
  final String message;

  const _PreviewError({required this.message});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(12),
    child: Text(message, textAlign: TextAlign.center),
  );
}
