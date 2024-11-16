import 'dart:math';

import 'package:crystal/models/git_models.dart';
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
  final double horizontalPadding = 32.0;
  late final double _gutterWidth;
  final int? hoveredLine;
  final double? hoverX;
  final double? hoverY;
  final Map<int, FileStatus> lineStatuses;

  final TextStyle _defaultStyle;
  final TextStyle _highlightStyle;

  GutterPainter({
    required this.editorState,
    required this.verticalOffset,
    required this.viewportHeight,
    required this.editorLayoutService,
    required this.editorConfigService,
    this.hoveredLine,
    this.hoverX,
    this.hoverY,
    Color? textColor,
    Color? highlightColor,
    required this.lineStatuses,
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

  void _drawGitDiffIndicator(Canvas canvas, int line, double y) {
    final status = lineStatuses[line];
    if (status == null) return;

    final paint = Paint()..style = PaintingStyle.fill;

    // Set color based on git status
    paint.color = switch (status) {
      FileStatus.added => Colors.green.withOpacity(0.7),
      FileStatus.modified => Colors.blue.withOpacity(0.7),
      FileStatus.deleted => Colors.red.withOpacity(0.7),
      _ => Colors.transparent,
    };

    // Draw indicator strip
    canvas.drawRect(
      Rect.fromLTWH(
        0, // Left edge of gutter
        y,
        4, // Width of indicator
        editorLayoutService.config.lineHeight,
      ),
      paint,
    );
  }

  bool _isIconHovered(double iconX, double iconY, double iconSize) {
    if (hoverX == null || hoverY == null) return false;
    final iconRect = Rect.fromLTWH(
      iconX - 4,
      iconY - 4,
      iconSize + 8,
      iconSize + 8,
    );
    return iconRect.contains(Offset(hoverX!, hoverY! + verticalOffset));
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

    const bufferLines = 20;
    final lineHeight = editorLayoutService.config.lineHeight;
    final firstVisibleVisualLine = (verticalOffset / lineHeight).floor();
    final visibleLinesInViewport = (viewportHeight / lineHeight).ceil();
    final lastVisibleVisualLine =
        firstVisibleVisualLine + visibleLinesInViewport + bufferLines;

    _drawContent(canvas, size, firstVisibleVisualLine, lastVisibleVisualLine);
  }

  void _drawContent(Canvas canvas, Size size, int firstVisibleVisualLine,
      int lastVisibleVisualLine) {
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

    final paint = Paint()
      ..color = _defaultStyle.color!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final highlightPaint = Paint()
      ..color =
          editorConfigService.themeService.currentTheme?.currentLineHighlight ??
              Colors.blue.withOpacity(0.2);

    int currentLine = 0;
    const bufferLines = 20;
    int visualLine = 0;

    while (visualLine <= lastVisibleVisualLine &&
        currentLine < editorState.buffer.lineCount) {
      if (editorState.isLineHidden(currentLine)) {
        currentLine++;
        continue;
      }

      if (visualLine >= firstVisibleVisualLine - bufferLines) {
        // Highlight current line first
        if (!editorState.editorSelectionManager.hasSelection() &&
            editorState.editorCursorManager.cursors
                .any((cursor) => cursor.line == currentLine)) {
          canvas.drawRect(
              Rect.fromLTWH(
                0,
                visualLine * editorLayoutService.config.lineHeight,
                size.width,
                editorLayoutService.config.lineHeight,
              ),
              highlightPaint);
        }

        _drawGitDiffIndicator(canvas, currentLine,
            visualLine * editorLayoutService.config.lineHeight);

        // Draw line number
        final lineNumber = (currentLine + 1).toString();
        final style = _getStyleForLine(currentLine);
        textPainter.text = TextSpan(text: lineNumber, style: style);
        textPainter.layout(maxWidth: _gutterWidth - (horizontalPadding * 2));

        final xOffset = size.width - textPainter.width - horizontalPadding;
        final yOffset = visualLine * editorLayoutService.config.lineHeight +
            (editorLayoutService.config.lineHeight - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(xOffset, yOffset));

        if (editorState.isFoldable(currentLine) ||
            editorState.isLineFolded(currentLine)) {
          final iconSize = editorConfigService.config.fontSize * 0.8;
          _drawFoldingIcon(
              canvas,
              paint,
              visualLine * editorLayoutService.config.lineHeight,
              iconSize,
              editorState.isLineFolded(currentLine),
              xOffset + textPainter.width + 10,
              currentLine == hoveredLine);

          if (editorState.isLineFolded(currentLine)) {
            _drawFoldPreview(
                canvas,
                currentLine,
                visualLine * editorLayoutService.config.lineHeight,
                iconSize,
                xOffset + textPainter.width + iconSize + 14);
          }
        }
      }
      visualLine++;
      currentLine++;
    }
  }

  TextStyle _getStyleForLine(int line) {
    if (editorState.editorSelectionManager.hasSelection()) {
      for (var selection in editorState.editorSelectionManager.selections) {
        int startLine = min(selection.anchorLine, selection.startLine);
        int endLine = max(selection.anchorLine, selection.endLine);
        if (line >= startLine && line <= endLine) {
          return _highlightStyle;
        }
      }
    } else if (editorState.editorCursorManager.cursors
        .any((cursor) => cursor.line == line)) {
      return _highlightStyle;
    }
    return _defaultStyle;
  }

  void _drawFoldPreview(
      Canvas canvas, int line, double y, double iconSize, double x) {
    final foldEnd = editorState.foldingRanges[line];
    if (foldEnd == null) return;

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
            x,
            y +
                (editorLayoutService.config.lineHeight - textPainter.height) /
                    2));
  }

  void _drawFoldingIcon(Canvas canvas, Paint paint, double y, double iconSize,
      bool isFolded, double x, bool isHovered) {
    final iconY = y + (editorLayoutService.config.lineHeight - iconSize) / 2;

    // Use the new hover check
    if (_isIconHovered(x, iconY, iconSize)) {
      final backgroundRect = Rect.fromLTWH(
        x - 4,
        iconY - 4,
        iconSize + 8,
        iconSize + 8,
      );

      canvas.drawRRect(
          RRect.fromRectAndRadius(backgroundRect, const Radius.circular(4)),
          Paint()
            ..color = editorConfigService.themeService.currentTheme?.primary
                    .withOpacity(0.2) ??
                Colors.blue.withOpacity(0.1)
            ..style = PaintingStyle.fill);
    }

    final rect = Rect.fromLTWH(
        x,
        y + (editorLayoutService.config.lineHeight - iconSize) / 2,
        iconSize,
        iconSize);

    final centerY = rect.top + rect.height / 2;
    final centerX = rect.left + rect.width / 2;
    final padding = iconSize * 0.25;
    final leftX = rect.left + padding;
    final rightX = rect.right - padding;
    final topY = rect.top + padding;
    final bottomY = rect.bottom - padding;

    if (isFolded) {
      final path = Path()
        ..moveTo(leftX, topY)
        ..lineTo(rightX, centerY)
        ..lineTo(leftX, bottomY);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    } else {
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

  @override
  bool shouldRepaint(GutterPainter oldDelegate) {
    return oldDelegate.hoveredLine != hoveredLine ||
        editorState.buffer.lineCount !=
            oldDelegate.editorState.buffer.lineCount ||
        editorState.editorCursorManager.cursors !=
            oldDelegate.editorState.editorCursorManager.cursors ||
        editorConfigService.config.fontSize !=
            oldDelegate.editorConfigService.config.fontSize ||
        editorState.foldingRanges != oldDelegate.editorState.foldingRanges ||
        verticalOffset != oldDelegate.verticalOffset;
  }
}
