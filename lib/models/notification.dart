import 'package:crystal/models/notifcation_type.dart';
import 'package:crystal/models/notification_action.dart';

class Notification {
  final String message;
  final NotificationType type;
  final Duration duration;
  final NotificationAction? action;

  Notification({
    required this.message,
    this.type = NotificationType.info,
    this.duration = const Duration(seconds: 3),
    this.action,
  });
}
