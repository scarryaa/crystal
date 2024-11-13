import 'dart:math';

import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SelectionPainter {
  final EditorState editorState;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  SelectionPainter(
    this.editorState, {
    required this.editorLayoutService,
    required this.editorConfigService,
  });

  void paint(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (!editorState.editorSelectionManager.hasSelection()) return;

    // Find the maximum selection line to ensure we render the full selection
    int maxSelectionLine = firstVisibleLine;
    for (var selection in editorState.editorSelectionManager.selections) {
      maxSelectionLine =
          max(maxSelectionLine, max(selection.startLine, selection.endLine));
    }

    // Extend lastVisibleLine if needed to show full selection
    lastVisibleLine = max(lastVisibleLine, maxSelectionLine + 1);

    for (var selection in editorState.editorSelectionManager.selections) {
      final (startLine, endLine, startColumn, endColumn) =
          _normalizeSelection(selection);

      // Calculate visual line position
      int visualLine = 0;
      for (int i = firstVisibleLine; i < startLine; i++) {
        if (!editorState.foldingState.isLineHidden(i)) {
          visualLine++;
        }
      }

      if (startLine == endLine) {
        _paintSingleLineSelection(canvas, startLine, startColumn, endColumn,
            firstVisibleLine, lastVisibleLine, visualLine);
      } else {
        _paintMultiLineSelection(canvas, startLine, endLine, startColumn,
            endColumn, firstVisibleLine, lastVisibleLine, visualLine);
      }
    }
  }

  void _paintSingleLineSelection(
      Canvas canvas,
      int line,
      int startColumn,
      int endColumn,
      int firstVisibleLine,
      int lastVisibleLine,
      int visualLine) {
    if (_isLineVisible(line, firstVisibleLine, lastVisibleLine)) {
      String lineText = editorState.buffer.getLine(line);
      double startX = _measureText(lineText.substring(0, startColumn));
      double width = _measureText(lineText.substring(startColumn, endColumn));

      if (width == 0) {
        width = editorConfigService.config.fontSize / 2;
      }

      canvas.drawRect(
          Rect.fromLTWH(
              startX,
              visualLine * editorLayoutService.config.lineHeight,
              width,
              editorLayoutService.config.lineHeight),
          Paint()
            ..color = editorConfigService.themeService.currentTheme?.primary
                    .withOpacity(0.2) ??
                Colors.blue.withOpacity(0.2));

      _drawWhitespaceIndicators(
          canvas, startColumn, endColumn, line, visualLine);
    }
  }

  void _paintMultiLineSelection(
      Canvas canvas,
      int startLine,
      int endLine,
      int startColumn,
      int endColumn,
      int firstVisibleLine,
      int lastVisibleLine,
      int initialVisualLine) {
    Paint selectionPaint = Paint()
      ..color = editorConfigService.themeService.currentTheme?.primary
              .withOpacity(0.2) ??
          Colors.blue.withOpacity(0.2);

    int visualLine = initialVisualLine;

    // Paint start line
    if (_isLineVisible(startLine, firstVisibleLine, lastVisibleLine)) {
      _paintSelectionLine(
          canvas, startLine, startColumn, null, visualLine, selectionPaint);
    }

    // Paint middle lines
    for (int line = startLine + 1; line < endLine; line++) {
      if (_isLineVisible(line, firstVisibleLine, lastVisibleLine)) {
        visualLine++;
        _paintSelectionLine(canvas, line, 0, null, visualLine, selectionPaint);
      } else if (!editorState.foldingState.isLineHidden(line)) {
        // Still increment visual line even if not visible
        visualLine++;
      }
    }

    // Paint end line
    if (_isLineVisible(endLine, firstVisibleLine, lastVisibleLine)) {
      if (!editorState.foldingState.isLineHidden(endLine)) {
        visualLine++;
        _paintSelectionLine(
            canvas, endLine, 0, endColumn, visualLine, selectionPaint);
      }
    }
  }

  void _paintSelectionLine(
    Canvas canvas,
    int line,
    int startColumn,
    int? endColumn,
    int visualLine,
    Paint paint,
  ) {
    String lineText = editorState.buffer.getLine(line);
    double startX =
        startColumn > 0 ? _measureText(lineText.substring(0, startColumn)) : 0;

    double width;
    if (endColumn != null) {
      width = _measureText(
          lineText.substring(startColumn, min(endColumn, lineText.length)));
    } else {
      width = _measureText(lineText.substring(startColumn));
    }

    if (width == 0) {
      width = editorConfigService.config.fontSize / 2;
    }

    canvas.drawRect(
        Rect.fromLTWH(
            startX,
            visualLine * editorLayoutService.config.lineHeight,
            width,
            editorLayoutService.config.lineHeight),
        paint);

    _drawWhitespaceIndicators(
        canvas, startColumn, endColumn ?? lineText.length, line, visualLine);
  }

  (int, int, int, int) _normalizeSelection(Selection selection) {
    if (selection.startLine > selection.endLine ||
        (selection.startLine == selection.endLine &&
            selection.startColumn > selection.endColumn)) {
      return (
        selection.endLine,
        selection.startLine,
        selection.endColumn,
        selection.startColumn
      );
    }
    return (
      selection.startLine,
      selection.endLine,
      selection.startColumn,
      selection.endColumn
    );
  }

  bool _isLineVisible(int line, int firstVisible, int lastVisible) {
    return line >= firstVisible &&
        line <= lastVisible &&
        !editorState.foldingState.isLineHidden(line);
  }

  double _measureText(String text) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

  void _drawWhitespaceIndicators(Canvas canvas, int startColumn, int endColumn,
      int lineNumber, int visualLine) {
    String lineText = editorState.buffer.getLine(lineNumber);

    for (int i = startColumn; i < min(endColumn, lineText.length); i++) {
      if (lineText[i] == ' ') {
        double xPos = _measureText(lineText.substring(0, i)) +
            (editorConfigService.config.fontSize / 4);

        _drawWhitespaceIndicator(
            canvas,
            xPos,
            visualLine * editorLayoutService.config.lineHeight +
                (editorLayoutService.config.lineHeight / 2));
      }
    }
  }

  void _drawWhitespaceIndicator(Canvas canvas, double left, double top) {
    canvas.drawCircle(
        Offset(left, top),
        editorConfigService.config.whitespaceIndicatorRadius,
        Paint()
          ..color = editorConfigService
                  .themeService.currentTheme?.whitespaceIndicatorColor ??
              Colors.black.withOpacity(0.5));
  }
}
