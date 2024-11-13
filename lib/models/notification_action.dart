import 'package:flutter/material.dart';

class NotificationAction {
  final String label;
  final VoidCallback onPressed;

  NotificationAction({
    required this.label,
    required this.onPressed,
  });
}
