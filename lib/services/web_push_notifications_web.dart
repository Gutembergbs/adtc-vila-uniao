import 'dart:js_interop';

import 'package:web/web.dart' as web;

void showForegroundNotification(String title, String body) {
  final notification = web.Notification(
    title,
    web.NotificationOptions(body: body),
  );
  notification.onclick = ((web.Event _) {
    web.window.focus();
  }).toJS;
}
