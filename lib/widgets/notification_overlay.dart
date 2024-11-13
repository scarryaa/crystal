import 'package:crystal/models/notifcation_type.dart';
import 'package:crystal/models/notification.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart' hide Notification;

class NotificationOverlay extends StatelessWidget {
  final List<Notification> notifications;
  final Function(Notification) onDismiss;
  final EditorConfigService editorConfigService;

  const NotificationOverlay({
    super.key,
    required this.notifications,
    required this.onDismiss,
    required this.editorConfigService,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 20,
      right: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: notifications.map((notification) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: NotificationCard(
              notification: notification,
              onDismiss: () => onDismiss(notification),
              editorConfigService: editorConfigService,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class NotificationCard extends StatelessWidget {
  final Notification notification;
  final VoidCallback onDismiss;
  final EditorConfigService editorConfigService;

  const NotificationCard({
    super.key,
    required this.notification,
    required this.onDismiss,
    required this.editorConfigService,
  });

  Color _getColor() {
    final theme = editorConfigService.themeService.currentTheme;

    if (theme == null) {
      switch (notification.type) {
        case NotificationType.success:
          return Colors.green;
        case NotificationType.warning:
          return Colors.orange;
        case NotificationType.error:
          return Colors.red;
        default:
          return Colors.grey;
      }
    }

    switch (notification.type) {
      case NotificationType.success:
        return theme.success;
      case NotificationType.warning:
        return theme.warning;
      case NotificationType.error:
        return theme.error;
      default:
        return theme.backgroundLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = editorConfigService.themeService.currentTheme;

    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: _getColor(),
          border: Border.all(
            color: editorConfigService.themeService.currentTheme!.textLight,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              notification.message,
              style: TextStyle(
                color:
                    theme?.text ?? Theme.of(context).textTheme.bodyLarge?.color,
                fontFamily: editorConfigService.config.uiFontFamily,
                fontSize: editorConfigService.config.uiFontSize,
              ),
            ),
            const SizedBox(width: 12),
            if (notification.action != null) ...[
              TextButton(
                onPressed: () {
                  notification.action!.onPressed();
                  onDismiss();
                },
                child: Text(
                  notification.action!.label,
                  style: TextStyle(
                    color:
                        editorConfigService.themeService.currentTheme!.primary,
                    fontFamily: editorConfigService.config.uiFontFamily,
                    fontSize: editorConfigService.config.uiFontSize,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: Icon(
                Icons.close,
                color: theme?.text ?? Theme.of(context).iconTheme.color,
                size: editorConfigService.config.uiFontSize,
              ),
              onPressed: onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
