import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SearchService {
  final VoidCallback scrollToCursor;

  SearchService({
    required this.scrollToCursor,
  });

  String searchTerm = '';
  List<SearchMatch> searchTermMatches = [];
  int currentSearchTermMatch = 0;
  bool caseSensitiveActive = false;
  bool wholeWordActive = false;
  bool regexActive = false;

  void onSearchTermChanged(String newTerm, EditorState? activeEditor) {
    searchTerm = newTerm;

    if (activeEditor?.buffer.lines != null) {
      searchTermMatches = findMatches(
        lines: activeEditor!.buffer.lines,
        searchTerm: newTerm,
        caseSensitive: caseSensitiveActive,
        wholeWord: wholeWordActive,
        useRegex: regexActive,
      );

      // Reset current match index when search term changes
      currentSearchTermMatch = 0;

      // If there are matches, position cursor at the first match
      if (searchTermMatches.isNotEmpty) {
        positionCursorAtMatch(searchTermMatches[0], activeEditor);
      }
    } else {
      searchTermMatches = [];
    }
    activeEditor?.clearSelection();
  }

  List<SearchMatch> findMatches({
    required List<String> lines,
    required String searchTerm,
    required bool caseSensitive,
    required bool wholeWord,
    required bool useRegex,
  }) {
    if (searchTerm.isEmpty || lines.isEmpty) {
      return [];
    }

    final List<SearchMatch> matches = [];

    // Prepare regex pattern based on search options
    RegExp? pattern;
    try {
      if (useRegex) {
        pattern = RegExp(
          searchTerm,
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      } else if (wholeWord) {
        // Escape special regex characters in the search term
        final escapedTerm = RegExp.escape(searchTerm);
        pattern = RegExp(
          r'\b' + escapedTerm + r'\b',
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      } else {
        // Escape special regex characters in the search term
        final escapedTerm = RegExp.escape(searchTerm);
        pattern = RegExp(
          escapedTerm,
          caseSensitive: caseSensitive,
          multiLine: true,
        );
      }
    } catch (e) {
      // Handle invalid regex pattern
      debugPrint('Invalid regex pattern: $e');
      return [];
    }

    // Process each line
    for (int lineNumber = 0; lineNumber < lines.length; lineNumber++) {
      final line = lines[lineNumber];
      if (line.isEmpty) continue;

      // Find all matches in the current line
      final Iterable<RegExpMatch> lineMatches = pattern.allMatches(line);

      for (final match in lineMatches) {
        matches.add(SearchMatch(
          lineNumber: lineNumber,
          startIndex: match.start,
          length: match.end - match.start,
        ));
      }
    }

    return matches;
  }

  int getNextMatchIndex(int currentIndex, int totalMatches) {
    if (totalMatches == 0) return 0;
    return (currentIndex + 1) % totalMatches;
  }

  int getPreviousMatchIndex(int currentIndex, int totalMatches) {
    if (totalMatches == 0) return 0;
    return currentIndex > 0 ? currentIndex - 1 : totalMatches - 1;
  }

  void nextSearchTerm(EditorState? activeEditor) {
    if (searchTermMatches.isEmpty) return;

    currentSearchTermMatch = getNextMatchIndex(
      currentSearchTermMatch,
      searchTermMatches.length,
    );

    // Position cursor at the current match
    positionCursorAtMatch(
        searchTermMatches[currentSearchTermMatch], activeEditor);
  }

  void previousSearchTerm(EditorState? activeEditor) {
    if (searchTermMatches.isEmpty) return;

    currentSearchTermMatch = getPreviousMatchIndex(
      currentSearchTermMatch,
      searchTermMatches.length,
    );

    // Position cursor at the current match
    positionCursorAtMatch(
        searchTermMatches[currentSearchTermMatch], activeEditor);
  }

  void positionCursorAtMatch(SearchMatch match, EditorState? activeEditor) {
    if (activeEditor == null) return;

    final matchLine = match.lineNumber;
    final matchEndColumn = match.startIndex + match.length;

    // Update cursor position to end of match
    activeEditor.clearAllCursors();
    activeEditor.addCursor(matchLine, matchEndColumn);

    // Update selection to cover the entire match
    activeEditor.editorSelectionManager.clearAll();
    activeEditor.editorSelectionManager.addSelection(Selection(
      startLine: matchLine,
      startColumn: match.startIndex,
      endLine: matchLine,
      endColumn: matchEndColumn,
      anchorLine: matchLine,
      anchorColumn: match.startIndex,
    ));

    scrollToCursor();
  }

  void toggleRegex(bool active, EditorState? activeEditor) {
    regexActive = active;
    onSearchTermChanged(searchTerm, activeEditor);
  }

  void toggleWholeWord(bool active, EditorState? activeEditor) {
    wholeWordActive = active;
    onSearchTermChanged(searchTerm, activeEditor);
  }

  void toggleCaseSensitive(bool active, EditorState? activeEditor) {
    caseSensitiveActive = active;
    onSearchTermChanged(searchTerm, activeEditor);
  }

  void replaceNextMatch(String newTerm, EditorState? activeEditor) {
    if (searchTermMatches.isEmpty) return;

    activeEditor?.buffer.replace(
        searchTermMatches[currentSearchTermMatch].lineNumber,
        searchTermMatches[currentSearchTermMatch].startIndex,
        searchTermMatches[currentSearchTermMatch].length,
        newTerm);
    onSearchTermChanged(searchTerm, activeEditor);
  }

  void replaceAllMatches(String newTerm, EditorState? activeEditor) {
    if (searchTermMatches.isEmpty) return;

    for (int i = 0; i < searchTermMatches.length; i++) {
      activeEditor?.buffer.replace(
          searchTermMatches[i].lineNumber,
          searchTermMatches[i].startIndex,
          searchTermMatches[i].length,
          newTerm);
    }
    onSearchTermChanged(searchTerm, activeEditor);
  }

  void updateSearchMatches(String newTerm, EditorState? activeEditor) {
    searchTerm = newTerm;

    if (activeEditor?.buffer.lines != null) {
      searchTermMatches = findMatches(
        lines: activeEditor!.buffer.lines,
        searchTerm: newTerm,
        caseSensitive: caseSensitiveActive,
        wholeWord: wholeWordActive,
        useRegex: regexActive,
      );
    }
  }
}
