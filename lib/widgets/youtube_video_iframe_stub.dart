import 'package:flutter/widgets.dart';

class YoutubeVideoIframe extends StatelessWidget {
  final String videoId;

  const YoutubeVideoIframe({super.key, required this.videoId});

  @override
  Widget build(BuildContext context) =>
      SizedBox.shrink(key: ValueKey<String>(videoId));
}
