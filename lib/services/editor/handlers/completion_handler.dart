import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/services/editor/completion_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:flutter/material.dart';

class CompletionManager {
  final ValueNotifier<int> selectedSuggestionIndexNotifier = ValueNotifier(0);
  final EditorCursorManager editorCursorManager;
  final Buffer buffer;
  final CompletionService completionService;
  final VoidCallback notifyListeners;

  List<CompletionItem> suggestions = [];
  bool showCompletions = false;

  CompletionManager({
    required this.editorCursorManager,
    required this.buffer,
    required this.completionService,
    required this.notifyListeners,
  });

  void selectNextSuggestion() {
    if (showCompletions && suggestions.isNotEmpty) {
      selectedSuggestionIndexNotifier.value =
          (selectedSuggestionIndexNotifier.value + 1) % suggestions.length;
      notifyListeners();
    }
  }

  void selectPreviousSuggestion() {
    if (showCompletions && suggestions.isNotEmpty) {
      selectedSuggestionIndexNotifier.value =
          (selectedSuggestionIndexNotifier.value - 1 + suggestions.length) %
              suggestions.length;
      notifyListeners();
    }
  }

  void resetSuggestionSelection() {
    selectedSuggestionIndexNotifier.value = 0;
    notifyListeners();
  }

  String _getPrefix(String line, int column) {
    final pattern = RegExp(r'\w+$');
    final match = pattern.firstMatch(line.substring(0, column));
    return match?.group(0) ?? '';
  }

  void updateCompletions() {
    if (editorCursorManager.cursors.isEmpty) {
      showCompletions = false;
      suggestions = [];
      notifyListeners();
      return;
    }

    final prefixes = editorCursorManager.cursors.map((cursor) {
      final line = buffer.getLine(cursor.line);
      return _getPrefix(line, cursor.column);
    }).toSet();

    if (prefixes.length == 1 && prefixes.first.isNotEmpty) {
      suggestions = completionService.getSuggestions(prefixes.first);
      showCompletions = suggestions.isNotEmpty &&
          (suggestions.length > 1 || suggestions[0].label != prefixes.first);
    } else {
      showCompletions = false;
      suggestions = [];
    }

    notifyListeners();
  }

  void acceptCompletion(CompletionItem item) {
    final sortedCursors = List<Cursor>.from(editorCursorManager.cursors)
      ..sort((a, b) => b.line.compareTo(a.line));

    for (var cursor in sortedCursors) {
      final line = buffer.getLine(cursor.line);
      final prefix = _getPrefix(line, cursor.column);

      if (prefix.isEmpty) continue;

      final newLine = line.substring(0, cursor.column - prefix.length) +
          item.label +
          line.substring(cursor.column);

      buffer.setLine(cursor.line, newLine);
      cursor.column = cursor.column - prefix.length + item.label.length;
    }

    showCompletions = false;
    resetSuggestionSelection();
    editorCursorManager.mergeCursorsIfNeeded();
    notifyListeners();
  }
}
