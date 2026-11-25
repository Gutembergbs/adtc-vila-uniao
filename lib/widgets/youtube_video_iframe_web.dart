import 'dart:ui_web' as ui;

import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

class YoutubeVideoIframe extends StatefulWidget {
  final String videoId;

  const YoutubeVideoIframe({super.key, required this.videoId});

  @override
  State<YoutubeVideoIframe> createState() => _YoutubeVideoIframeState();
}

class _YoutubeVideoIframeState extends State<YoutubeVideoIframe> {
  static int _nextViewId = 0;

  late final String _viewType;

  @override
  void initState() {
    super.initState();
    _viewType = 'youtube-video-${_nextViewId++}';

    final iframe = web.HTMLIFrameElement()
      ..src =
          'https://www.youtube-nocookie.com/embed/${Uri.encodeComponent(widget.videoId)}'
          '?playsinline=1&controls=1'
      ..title = 'Vídeo do YouTube'
      ..allow =
          'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share'
      ..allowFullscreen = true
      ..referrerPolicy = 'strict-origin-when-cross-origin'
      ..style.border = '0'
      ..style.display = 'block'
      ..style.height = '100%'
      ..style.width = '100%';

    ui.platformViewRegistry.registerViewFactory(_viewType, (int _) => iframe);
  }

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: HtmlElementView(viewType: _viewType),
  );
}
