import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:flutter/material.dart';

class SearchPainter {
  final String searchTerm;
  final List<SearchMatch> searchTermMatches;
  final int currentSearchTermMatch;
  final EditorLayoutService editorLayoutService;

  const SearchPainter({
    required this.searchTerm,
    required this.searchTermMatches,
    required this.currentSearchTermMatch,
    required this.editorLayoutService,
  });

  void paint(Canvas canvas, String searchTerm, int startLine, int endLine) {
    if (searchTerm.isEmpty) return;

    for (int i = 0; i < searchTermMatches.length; i++) {
      if (searchTermMatches[i].lineNumber >= startLine &&
          searchTermMatches[i].lineNumber <= endLine) {
        var left = searchTermMatches[i].startIndex * EditorConstants.charWidth;
        var top = searchTermMatches[i].lineNumber *
            editorLayoutService.config.lineHeight;
        var width = searchTerm.length * EditorConstants.charWidth;
        var height = editorLayoutService.config.lineHeight;

        canvas.drawRect(
            Rect.fromLTWH(left, top, width, height),
            Paint()
              ..color = i == currentSearchTermMatch
                  ? Colors.blue.withOpacity(0.4)
                  : Colors.blue.withOpacity(0.2));
      }
    }
  }
}
