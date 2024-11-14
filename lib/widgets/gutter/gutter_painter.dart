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

    final lineHeight = editorLayoutService.config.lineHeight;
    final visibleLinesInViewport = (viewportHeight / lineHeight).ceil();
// Add buffer lines for smooth scrolling
    final targetVisibleLines = visibleLinesInViewport + 30;

    int visibleLineCount = 0;

    while (visibleLineCount < targetVisibleLines &&
        lastVisibleLine < editorState.buffer.lineCount) {
      if (!editorState.isLineHidden(lastVisibleLine)) {
        visibleLineCount++;
      }
      lastVisibleLine++;
    }

    // Add buffer but respect actual content bounds
    lastVisibleLine = min(lastVisibleLine + 20, editorState.buffer.lineCount);

    _drawText(canvas, size, firstVisibleLine, lastVisibleLine);

    for (var i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (!editorState.isLineHidden(i)) {
        _drawFoldingIndicators(canvas, size, i);
      }
    }

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

  void _drawFoldingIndicators(Canvas canvas, Size size, int line) {
    if (line >= editorState.buffer.lines.length) return;

    final isFoldable = editorState.isFoldable(line);
    final isFolded = editorState.isLineFolded(line);

    if (!isFoldable && !isFolded) return;

    final paint = Paint()
      ..color = _defaultStyle.color!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Calculate visual position for the indicator
    int visualLine = 0;
    for (int i = 0; i < line; i++) {
      if (!editorState.isLineHidden(i)) {
        visualLine++;
      }
    }

    final y = visualLine * editorLayoutService.config.lineHeight;
    final iconSize = editorConfigService.config.fontSize * 0.8;

    _drawFoldingIcon(canvas, paint, y, iconSize, isFolded);

    if (isFolded) {
      _drawFoldPreview(canvas, line, y, iconSize);
    }
  }

  void _drawFoldPreview(Canvas canvas, int line, double y, double iconSize) {
    final foldEnd = editorState.foldingRanges[line];
    if (foldEnd == null) return;

    // Count visible lines in fold
    int foldedLines = 0;
    for (int i = line + 1; i <= foldEnd; i++) {
      if (!editorState.isLineHidden(i)) {
        foldedLines++;
      }
    }

    if (foldedLines == 0) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: '⋯ $foldedLines lines',
        style: TextStyle(
          color: _defaultStyle.color!.withOpacity(0.7),
          fontSize: editorConfigService.config.fontSize * 0.9,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    textPainter.paint(
        canvas,
        Offset(
            iconSize + 12,
            y +
                (editorLayoutService.config.lineHeight - textPainter.height) /
                    2));
  }

  void _drawFoldingIcon(
      Canvas canvas, Paint paint, double y, double iconSize, bool isFolded) {
    // Create a slightly smaller rect for better visual balance
    final rect = Rect.fromLTWH(
        4.0,
        y + (editorLayoutService.config.lineHeight - iconSize) / 2,
        iconSize,
        iconSize);

    // Calculate center points more precisely
    final centerY = rect.top + rect.height / 2;
    final centerX = rect.left + rect.width / 2;

    // Add padding from edges for better appearance
    final padding = iconSize * 0.25;
    final leftX = rect.left + padding;
    final rightX = rect.right - padding;
    final topY = rect.top + padding;
    final bottomY = rect.bottom - padding;

    if (isFolded) {
      // Right-pointing chevron (>) with smoother angles
      final path = Path()
        ..moveTo(leftX, topY)
        ..lineTo(rightX, centerY)
        ..lineTo(leftX, bottomY);

      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    } else {
      // Down-pointing chevron (v) with smoother angles
      final path = Path()
        ..moveTo(leftX, topY)
        ..lineTo(centerX, bottomY)
        ..lineTo(rightX, topY);

      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
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

    // Track both buffer position and visual position
    int visualLine = 0;

    for (int i = 0; i < firstVisibleLine; i++) {
      if (!editorState.isLineHidden(i)) {
        visualLine++;
      }
    }

    for (int currentLine = firstVisibleLine;
        currentLine < lastVisibleLine;
        currentLine++) {
      // Skip hidden lines
      if (editorState.isLineHidden(currentLine)) {
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
      if (!editorState.isLineHidden(i)) {
        visualLine++;
      }
    }

    // Only draw if line is not hidden
    if (!editorState.isLineHidden(lineNumber)) {
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

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return editorState.buffer.lineCount !=
            oldDelegate.editorState.buffer.lineCount ||
        editorState.editorCursorManager.cursors !=
            oldDelegate.editorState.editorCursorManager.cursors ||
        editorConfigService.config.fontSize !=
            oldDelegate.editorConfigService.config.fontSize ||
        editorState.foldingRanges != oldDelegate.editorState.foldingRanges ||
        verticalOffset != oldDelegate.verticalOffset;
  }
}
