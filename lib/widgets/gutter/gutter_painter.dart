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
    _drawBackground(canvas, size);

    int firstVisibleLine = max(0,
        (verticalOffset / editorLayoutService.config.lineHeight).floor() - 20);

    // Calculate last visible line with proper bounds
    int lastVisibleLine = firstVisibleLine;
    double currentHeight = 0;

    while (currentHeight <
            viewportHeight + (editorLayoutService.config.lineHeight * 30) &&
        lastVisibleLine < editorState.buffer.lineCount) {
      if (!editorState.foldingState.isLineHidden(lastVisibleLine)) {
        currentHeight += editorLayoutService.config.lineHeight;
        // Break if we've exceeded the actual content height
        if (currentHeight > size.height) {
          break;
        }
      }
      lastVisibleLine++;
    }

    // Add buffer but respect actual content bounds
    lastVisibleLine = min(lastVisibleLine + 20, editorState.buffer.lineCount);

    _drawText(canvas, size, firstVisibleLine, lastVisibleLine);

    for (var i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        _drawFoldingIndicators(canvas, size, i);
      }
    }

    // Draw highlights
    if (!editorState.editorSelectionManager.hasSelection()) {
      _currentHighlightedLines.clear();
      for (var cursor in editorState.editorCursorManager.cursors) {
        if (!_currentHighlightedLines.contains(cursor.line) &&
            !editorState.foldingState.isLineHidden(cursor.line)) {
          _highlightCurrentLine(canvas, size, cursor.line);
          _currentHighlightedLines.add(cursor.line);
        }
      }
    }
  }

  void _drawFoldingIndicators(Canvas canvas, Size size, int line) {
    if (_isFoldable(line)) {
      final isFolded = editorState.foldingState.isLineFolded(line);
      final paint = Paint()
        ..color = _defaultStyle.color!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // Calculate visual position for the indicator
      int visualLine = 0;
      for (int i = 0; i < line; i++) {
        if (!editorState.foldingState.isLineHidden(i)) {
          visualLine++;
        }
      }

      final y = visualLine * editorLayoutService.config.lineHeight;
      final iconSize = editorConfigService.config.fontSize * 0.8;
      final rect = Rect.fromLTWH(
          4.0,
          y + (editorLayoutService.config.lineHeight - iconSize) / 2,
          iconSize,
          iconSize);

      // Draw box
      canvas.drawRect(rect, paint);

      // Draw plus/minus
      final centerX = rect.left + rect.width / 2;
      final centerY = rect.top + rect.height / 2;
      canvas.drawLine(Offset(rect.left + 2, centerY),
          Offset(rect.right - 2, centerY), paint);

      if (isFolded) {
        canvas.drawLine(Offset(centerX, rect.top + 2),
            Offset(centerX, rect.bottom - 2), paint);
      }
    }
  }

  bool _isFoldable(int line) {
    if (line >= editorState.buffer.lines.length) return false;

    final currentLine = editorState.buffer.lines[line].trim();

    // Skip empty lines
    if (currentLine.isEmpty) return false;

    // Check if the current line ends with a block starter
    if (!currentLine.endsWith('{') &&
        !currentLine.endsWith('(') &&
        !currentLine.endsWith('[')) {
      return false;
    }

    final currentIndent = _getIndentation(editorState.buffer.lines[line]);

    // Look ahead to find a valid folding range
    int nextLine = line + 1;
    bool hasContent = false;

    while (nextLine < editorState.buffer.lines.length) {
      final nextLineText = editorState.buffer.lines[nextLine];
      if (nextLineText.trim().isEmpty) {
        nextLine++;
        continue;
      }

      final nextIndent = _getIndentation(nextLineText);

      // If we find a line with less indentation, this is not foldable
      if (nextIndent <= currentIndent) {
        return hasContent;
      }

      hasContent = true;
      nextLine++;
    }

    return false;
  }

  int _getIndentation(String line) {
    // Count leading spaces and tabs
    int indent = 0;
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        indent++;
      } else if (line[i] == '\t') {
        indent += 4;
      } else {
        break;
      }
    }
    return indent;
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

    // Track both buffer position and visual position
    int visualLine = 0;

    for (int i = 0; i < firstVisibleLine; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        visualLine++;
      }
    }

    for (int currentLine = firstVisibleLine;
        currentLine < lastVisibleLine;
        currentLine++) {
      // Skip hidden lines
      if (editorState.foldingState.isLineHidden(currentLine)) {
        continue;
      }

      final lineNumber = (currentLine + 1).toString();
      final style = editorState.editorCursorManager.cursors
              .any((cursor) => cursor.line == currentLine)
          ? _highlightStyle
          : _defaultStyle;

      textPainter.text = TextSpan(
        text: lineNumber,
        style: style,
      );

      textPainter.layout(maxWidth: _gutterWidth - (horizontalPadding * 2));

      final xOffset = size.width - textPainter.width - horizontalPadding;
      final yOffset = visualLine * editorLayoutService.config.lineHeight +
          (editorLayoutService.config.lineHeight - textPainter.height) / 2;

      textPainter.paint(canvas, Offset(xOffset, yOffset));

      visualLine++;
    }
  }

  void _highlightCurrentLine(Canvas canvas, Size size, int lineNumber) {
    // Convert buffer line to visual line
    int visualLine = 0;
    for (int i = 0; i < lineNumber; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
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

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return editorState.buffer.lineCount !=
            oldDelegate.editorState.buffer.lineCount ||
        editorState.editorCursorManager.cursors !=
            oldDelegate.editorState.editorCursorManager.cursors ||
        editorConfigService.config.fontSize !=
            oldDelegate.editorConfigService.config.fontSize ||
        editorState.foldingState.foldingRanges !=
            oldDelegate.editorState.foldingState.foldingRanges ||
        verticalOffset != oldDelegate.verticalOffset;
  }
}
