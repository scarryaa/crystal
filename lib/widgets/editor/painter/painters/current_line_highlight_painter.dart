import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class CurrentLineHighlightPainter extends EditorPainterBase {
  EditorState editorState;
  final Set<int> _currentHighlightedLines = {};

  CurrentLineHighlightPainter(
      {required this.editorState,
      required super.editorLayoutService,
      required super.editorConfigService});

  @override
  void paint(Canvas canvas, Size size,
      {required int firstVisibleLine, required int lastVisibleLine}) {
    // Clear previous highlighted lines
    _currentHighlightedLines.clear();

    // Draw highlights
    if (!editorState.editorSelectionManager.hasSelection()) {
      _currentHighlightedLines.clear();
      for (var cursor in editorState.cursors) {
        // Only highlight if line is not hidden and not already highlighted
        if (!_currentHighlightedLines.contains(cursor.line) &&
            !editorState.isLineHidden(cursor.line)) {
          _highlightCurrentLine(canvas, size, cursor.line);
          _currentHighlightedLines.add(cursor.line);
        }
      }
    }
  }

  void _highlightCurrentLine(Canvas canvas, Size size, int lineNumber) {
    // Skip if line is hidden
    if (editorState.isLineHidden(lineNumber)) return;

    // Calculate visual position
    int visualLine = 0;
    for (int i = 0; i < lineNumber; i++) {
      if (!editorState.isLineHidden(i)) {
        visualLine++;
      }
    }

    canvas.drawRect(
        Rect.fromLTWH(
          0,
          visualLine * editorLayoutService.config.lineHeight,
          size.width,
          editorLayoutService.config.lineHeight,
        ),
        Paint()
          ..color = editorConfigService
                  .themeService.currentTheme?.currentLineHighlight ??
              Colors.blue.withOpacity(0.2));
  }
}
