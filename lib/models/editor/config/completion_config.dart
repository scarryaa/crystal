import 'package:crystal/models/editor/completion_item.dart';

class CompletionConfig {
  final List<CompletionItem> suggestions;
  final Function(CompletionItem) onSelect;
  final int selectedIndex;

  CompletionConfig({
    required this.suggestions,
    required this.onSelect,
    required this.selectedIndex,
  });
}
