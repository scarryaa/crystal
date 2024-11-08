import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class GutterPainter extends CustomPainter {
  final EditorState editorState;
  final double verticalOffset;
  final double viewportHeight;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final Set<int> _currentHighlightedLines = {};
  final double horizontalPadding = 16.0;
  late final double _gutterWidth;

  final TextStyle _defaultStyle;
  final TextStyle _highlightStyle;

  GutterPainter({
    required this.editorState,
    required this.verticalOffset,
    required this.viewportHeight,
    required this.editorLayoutService,
    required this.editorConfigService,
    Color? textColor,
    Color? highlightColor,
  })  : _defaultStyle = TextStyle(
          color: textColor ?? Colors.grey[600],
          fontSize: editorConfigService.config.fontSize,
          fontFamily: editorConfigService.config.fontFamily,
        ),
        _highlightStyle = TextStyle(
          color: highlightColor ?? Colors.blue,
          fontSize: editorConfigService.config.fontSize,
          fontFamily: editorConfigService.config.fontFamily,
        ),
        super(repaint: editorState) {
    _gutterWidth = _calculateGutterWidth();
  }

  double _calculateGutterWidth() {
    final lineCount = editorState.buffer.lineCount;
    final maxLineNumberWidth = _getTextWidth(
      lineCount.toString(),
      _defaultStyle,
    );
    return maxLineNumberWidth + (horizontalPadding * 2);
  }

  double _getTextWidth(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width;
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    _drawBackground(canvas, size);

    // Calculate visible lines
    int firstVisibleLine = max(0,
        (verticalOffset / editorLayoutService.config.lineHeight).floor() - 5);
    int lastVisibleLine = min(
        editorState.buffer.lineCount,
        ((verticalOffset + viewportHeight) /
                    editorLayoutService.config.lineHeight)
                .ceil() +
            5);
    lastVisibleLine = lastVisibleLine.clamp(0, editorState.buffer.lineCount);

    _drawText(canvas, size, firstVisibleLine, lastVisibleLine);

    // Highlight current line (if no selection)
    if (!editorState.editorSelectionManager.hasSelection()) {
      for (var cursor in editorState.editorCursorManager.cursors) {
        if (!_currentHighlightedLines.contains(cursor.line)) {
          _highlightCurrentLine(canvas, size, cursor.line);
          _currentHighlightedLines.add(cursor.line);
        }
      }
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
          ..color = editorConfigService.themeService.currentTheme != null
              ? editorConfigService.themeService.currentTheme!.background
              : Colors.white);
  }

  void _drawText(
      Canvas canvas, Size size, int firstVisibleLine, int lastVisibleLine) {
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      maxLines: 1,
      textHeightBehavior: const TextHeightBehavior(
        applyHeightToFirstAscent: false,
        applyHeightToLastDescent: false,
      ),
      strutStyle: StrutStyle(
        fontSize: editorConfigService.config.fontSize,
        fontFamily: editorConfigService.config.fontFamily,
        height: 1.0,
        forceStrutHeight: true,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );

    for (var i = firstVisibleLine; i < lastVisibleLine; i++) {
      final lineNumber = (i + 1).toString();
      final isLineInSelection = editorState.editorSelectionManager.selections
          .any((selection) =>
              i >= selection.startLine && i <= selection.endLine);
      final style = editorState.editorCursorManager.cursors
                  .any((cursor) => cursor.line == i) ||
              isLineInSelection
          ? _highlightStyle
          : _defaultStyle;

      textPainter.text = TextSpan(
        text: lineNumber,
        style: style,
      );

      textPainter.layout(maxWidth: _gutterWidth - (horizontalPadding * 2));

      final xOffset = size.width - textPainter.width - horizontalPadding;
      final yOffset = i * editorLayoutService.config.lineHeight +
          (editorLayoutService.config.lineHeight - textPainter.height) / 2;

      textPainter.paint(
        canvas,
        Offset(xOffset, yOffset),
      );
    }
  }

  void _highlightCurrentLine(Canvas canvas, Size size, int lineNumber) {
    canvas.drawRect(
        Rect.fromLTWH(
          0,
          lineNumber * editorLayoutService.config.lineHeight,
          size.width,
          editorLayoutService.config.lineHeight,
        ),
        Paint()
          ..color = editorConfigService.themeService.currentTheme != null
              ? editorConfigService
                  .themeService.currentTheme!.currentLineHighlight
              : Colors.blue.withOpacity(0.2));
  }

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return editorState.buffer.lineCount !=
            oldDelegate.editorState.buffer.lineCount ||
        editorState.editorCursorManager.cursors !=
            oldDelegate.editorState.editorCursorManager.cursors ||
        editorConfigService.config.fontSize !=
            oldDelegate.editorConfigService.config.fontSize;
  }
}
