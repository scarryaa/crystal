import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/completion_item_kind.dart';
import 'package:crystal/state/editor/editor_state.dart';

class CompletionService {
  final EditorState editor;

  CompletionService(this.editor);

  List<CompletionItem> getSuggestions(String prefix) {
    final suggestions = <CompletionItem>[];
    final seenLabels = <String>{};

    for (final item in _getKeywordSuggestions(prefix)) {
      if (!seenLabels.contains(item.label)) {
        suggestions.add(item);
        seenLabels.add(item.label);
      }
    }

    for (final item in _getLocalSuggestions(prefix)) {
      if (!seenLabels.contains(item.label)) {
        suggestions.add(item);
        seenLabels.add(item.label);
      }
    }

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
    final uniqueWords = <String>{};

    for (final match in matches) {
      final word = match.group(0)!;
      if (word.startsWith(prefix)) {
        uniqueWords.add(word);
      }
    }

    return uniqueWords
        .map((word) => CompletionItem(
              label: word,
              kind: CompletionItemKind.variable,
              detail: 'Local',
            ))
        .toList();
  }
}
