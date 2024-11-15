import 'package:crystal/models/editor/completion_item_kind.dart';

class CompletionItem {
  final String label;
  final CompletionItemKind kind;
  final String detail;
  final String? documentation;
  final String? insertText;
  final List<String>? parameters;

  const CompletionItem({
    required this.label,
    required this.kind,
    required this.detail,
    this.documentation,
    this.insertText,
    this.parameters,
  });
}
