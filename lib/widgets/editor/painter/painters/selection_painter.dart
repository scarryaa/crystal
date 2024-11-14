import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class SelectionPainter {
  final EditorState editorState;
  final TextPainter _textPainter;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  // Reuse the same TextStyle
  late final TextStyle _measureStyle;

  SelectionPainter(
    this.editorState, {
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
        ) {
    _measureStyle = TextStyle(
      fontFamily: editorConfigService.config.fontFamily,
      fontSize: editorConfigService.config.fontSize,
      fontWeight: FontWeight.normal,
    );
    _textPainter.text = TextSpan(style: _measureStyle);
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

    if (lineText.isEmpty) {
      canvas.drawRect(
          Rect.fromLTWH(
              0,
              visualLine * editorLayoutService.config.lineHeight,
              editorConfigService.config.fontSize / 2,
              editorLayoutService.config.lineHeight),
          paint);
      return;
    }

    startColumn = startColumn.clamp(0, lineText.length);
    endColumn = endColumn?.clamp(0, lineText.length);

    // Calculate positions more efficiently
    double startX = 0;
    if (startColumn > 0) {
      startX = startColumn * editorLayoutService.config.charWidth;
    }

    double width;
    if (endColumn != null && startColumn < endColumn) {
      width = (endColumn - startColumn) * editorLayoutService.config.charWidth;
    } else {
      width = (lineText.length - startColumn) *
          editorLayoutService.config.charWidth;
    }

    // Batch draw operations
    canvas.drawRect(
        Rect.fromLTWH(
            startX,
            visualLine * editorLayoutService.config.lineHeight,
            width,
            editorLayoutService.config.lineHeight),
        paint);

    // Only draw whitespace indicators if configured
    _drawWhitespaceIndicators(
        canvas, startColumn, endColumn ?? lineText.length, line, visualLine);
  }

  (int, int, int, int) _normalizeSelection(var selection) {
    int startLine = selection.startLine;
    int endLine = selection.endLine;

    // Add a bounds check here
    endLine = endLine.clamp(0, editorState.buffer.lineCount - 1);

    int startColumn = selection.startColumn;
    int endColumn = selection.endColumn;

    if (startLine > endLine ||
        (startLine == endLine && startColumn > endColumn)) {
      return (endLine, startLine, endColumn, startColumn);
    }
    return (startLine, endLine, startColumn, endColumn);
  }

  void _paintSingleLineSelection(
    Canvas canvas,
    int line,
    int startColumn,
    int endColumn,
    int visualLine,
  ) {
    if (editorState.isLineHidden(line)) return;

    _paintSelectionLine(
        canvas,
        line,
        startColumn,
        endColumn,
        visualLine,
        Paint()
          ..color = editorConfigService.themeService.currentTheme?.primary
                  .withOpacity(0.2) ??
              Colors.blue.withOpacity(0.2));
  }

  void _drawWhitespaceIndicators(
    Canvas canvas,
    int startColumn,
    int endColumn,
    int line,
    int visualLine,
  ) {
    final lineText = editorState.buffer.getLine(line);

    // Pre-calculate the base width once
    double baseWidth = editorLayoutService.config.charWidth;

    for (int i = startColumn; i < endColumn && i < lineText.length; i++) {
      if (lineText[i] == ' ') {
        double x = i * baseWidth + baseWidth / 2;
        _drawWhitespaceIndicator(
            canvas,
            x,
            visualLine * editorLayoutService.config.lineHeight +
                editorLayoutService.config.lineHeight / 2);
      }
    }
  }

  void _drawWhitespaceIndicator(Canvas canvas, double left, double top) {
    canvas.drawCircle(
        Offset(left,
            top + editorConfigService.config.whitespaceIndicatorRadius / 2),
        editorConfigService.config.whitespaceIndicatorRadius,
        Paint()
          ..color = editorConfigService.themeService.currentTheme != null
              ? editorConfigService
                  .themeService.currentTheme!.whitespaceIndicatorColor
              : Colors.black.withOpacity(0.5));
  }

  void paint(Canvas canvas, int firstVisibleLine, int lastVisibleLine) {
    if (!editorState.editorSelectionManager.hasSelection()) return;

    const bufferLines = 5;
    int visualLine = 0;
    int startLine = 0;

    // Find the first actual line to start painting
    while (startLine < editorState.buffer.lineCount &&
        visualLine < firstVisibleLine - bufferLines) {
      if (!editorState.isLineHidden(startLine)) {
        visualLine++;
      }
      startLine++;
    }

    visualLine = max(0, firstVisibleLine - bufferLines);

    for (var selection in editorState.editorSelectionManager.selections) {
      final (selStartLine, selEndLine, startColumn, endColumn) =
          _normalizeSelection(selection);

      for (int line = startLine; line < editorState.buffer.lineCount; line++) {
        if (editorState.isLineHidden(line)) continue;

        if (line > selEndLine) break;

        if (line >= selStartLine && line <= selEndLine) {
          if (selStartLine == selEndLine) {
            _paintSingleLineSelection(
                canvas, line, startColumn, endColumn, visualLine);
          } else if (line == selStartLine) {
            _paintSelectionLine(canvas, line, startColumn, null, visualLine,
                _getSelectionPaint());
          } else if (line == selEndLine) {
            _paintSelectionLine(
                canvas, line, 0, endColumn, visualLine, _getSelectionPaint());
          } else {
            _paintSelectionLine(
                canvas, line, 0, null, visualLine, _getSelectionPaint());
          }
        }

        visualLine++;
        if (visualLine > lastVisibleLine + bufferLines) break;
      }
    }
  }

  Paint _getSelectionPaint() {
    return Paint()
      ..color = editorConfigService.themeService.currentTheme?.primary
              .withOpacity(0.2) ??
          Colors.blue.withOpacity(0.2);
  }
}
