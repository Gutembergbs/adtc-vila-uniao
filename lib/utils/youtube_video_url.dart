String? youtubeVideoIdFromUrl(String? value) {
  final uri = Uri.tryParse(value?.trim() ?? '');
  if (uri == null ||
      !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }

  final host = uri.host.toLowerCase();
  final pathSegments = uri.pathSegments;
  String? videoId;

  if (host == 'youtu.be' || host == 'www.youtu.be') {
    if (pathSegments.isNotEmpty) videoId = pathSegments.first;
  } else if ({
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  }.contains(host)) {
    if (pathSegments.isNotEmpty && pathSegments.first == 'watch') {
      videoId = uri.queryParameters['v'];
    } else if (pathSegments.length > 1 &&
        {'embed', 'live', 'shorts', 'v'}.contains(pathSegments.first)) {
      videoId = pathSegments[1];
    }
  }

  if (videoId == null || !RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(videoId)) {
    return null;
  }

  return videoId;
}
