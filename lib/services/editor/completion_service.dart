import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/completion_item_kind.dart';
import 'package:crystal/state/editor/editor_state.dart';

class CompletionService {
  final EditorState editor;

  CompletionService(this.editor);

  List<CompletionItem> getSuggestions(String prefix) {
    final suggestions = <CompletionItem>[];
    suggestions.addAll(_getKeywordSuggestions(prefix));
    suggestions.addAll(_getLocalSuggestions(prefix));
    return suggestions;
  }

  List<CompletionItem> _getKeywordSuggestions(String prefix) {
    final keywords = ['if', 'else', 'for', 'while', 'class', 'function'];
    return keywords
        .where((k) => k.startsWith(prefix))
        .map((k) => CompletionItem(
              label: k,
              kind: CompletionItemKind.keyword,
              detail: 'Keyword',
            ))
        .toList();
  }

  List<CompletionItem> _getLocalSuggestions(String prefix) {
    final pattern = RegExp(r'\b\w+\b');
    final matches = pattern.allMatches(editor.buffer.content);

    return matches
        .map((m) => m.group(0)!)
        .where((word) => word.startsWith(prefix))
        .map((word) => CompletionItem(
              label: word,
              kind: CompletionItemKind.variable,
              detail: 'Local',
            ))
        .toList();
  }
}
