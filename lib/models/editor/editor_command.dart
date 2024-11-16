class EditorCommand {
  final String id;
  final String label;
  final String? shortcut;
  final String? detail;
  final String? category;
  final Function() action;

  EditorCommand({
    required this.id,
    required this.label,
    this.shortcut,
    this.detail,
    this.category,
    required this.action,
  });
}
