import 'package:crystal/models/notifcation_type.dart';
import 'package:crystal/models/notification.dart';
import 'package:crystal/models/notification_action.dart';
import 'package:flutter/material.dart' hide Notification;

class NotificationService extends ChangeNotifier {
  final List<Notification> _notifications = [];
  List<Notification> get notifications => _notifications;

  void show(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    NotificationAction? action,
  }) {
    final notification = Notification(
      message: message,
      type: type,
      duration: duration,
      action: action,
    );
    _notifications.add(notification);
    notifyListeners();

    Future.delayed(duration, () {
      _notifications.remove(notification);
      notifyListeners();
    });
  }

  void dismiss(Notification notification) {
    _notifications.remove(notification);
    notifyListeners();
  }
}
