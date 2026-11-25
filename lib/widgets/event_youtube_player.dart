import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import 'youtube_video_iframe_stub.dart'
    if (dart.library.js_interop) 'youtube_video_iframe_web.dart';

class EventYoutubePlayer extends StatefulWidget {
  final String videoId;

  const EventYoutubePlayer({super.key, required this.videoId});

  @override
  State<EventYoutubePlayer> createState() => _EventYoutubePlayerState();
}

class _EventYoutubePlayerState extends State<EventYoutubePlayer> {
  YoutubePlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = YoutubePlayerController.fromVideoId(
        videoId: widget.videoId,
        autoPlay: false,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          privacyEnhancedMode: true,
          interfaceLanguage: 'pt',
          captionLanguage: 'pt',
        ),
      );
    }
  }

  @override
  void dispose() {
    _controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: kIsWeb
        ? YoutubeVideoIframe(videoId: widget.videoId)
        : YoutubePlayer(controller: _controller!, aspectRatio: 16 / 9),
  );
}
