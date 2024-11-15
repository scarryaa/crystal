import 'dart:ui';

class EditorCommand {
  final String id;
  final String label;
  final String? shortcut;
  final VoidCallback action;

  EditorCommand({
    required this.id,
    required this.label,
    this.shortcut,
    required this.action,
  });
}
