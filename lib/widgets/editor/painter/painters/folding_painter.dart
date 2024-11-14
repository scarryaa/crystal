import 'dart:math';

import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:crystal/widgets/editor/painter/painters/text_painter_helper.dart';
import 'package:flutter/material.dart';

class FoldingPainter extends EditorPainterBase {
  final TextPainterHelper textPainterHelper;
  final Map<int, int> foldedRegions;

  FoldingPainter({
    required super.editorLayoutService,
    required super.editorConfigService,
    required this.textPainterHelper,
    required this.foldedRegions,
  });

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  }) {
    assert(firstVisibleLine >= 0, 'firstVisibleLine must be non-negative');
    assert(lastVisibleLine >= firstVisibleLine,
        'lastVisibleLine must be >= firstVisibleLine');
    assert(size.height > 0, 'Canvas size must have positive height');

    // Add buffer zones above and below visible area
    final extendedFirstLine = max(0, firstVisibleLine - 5);
    final extendedLastLine = lastVisibleLine + 5;

    // Sort folding regions by start line to handle nested folds correctly
    final sortedRegions = foldedRegions.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedRegions) {
      final startLine = entry.key;
      final endLine = entry.value;

      // Check if any part of the folded region is visible
      if ((startLine >= extendedFirstLine && startLine <= extendedLastLine) ||
          (endLine >= extendedFirstLine && endLine <= extendedLastLine) ||
          (startLine <= extendedFirstLine && endLine >= extendedLastLine)) {
        // Only draw if the line itself is not hidden (inside another fold)
        if (!textPainterHelper.isLineHidden(startLine)) {
          _drawFoldedRegionIndicator(
            canvas,
            startLine,
            endLine - startLine,
          );
        }
      }
    }
  }

  void _drawFoldedRegionIndicator(Canvas canvas, int startLine, int lineCount) {
    // First check if startLine is valid
    if (startLine < 0 ||
        startLine >= textPainterHelper.editorState.buffer.lines.length) {
      return;
    }

    // Calculate visual line position accounting for all folded regions
    int visualLine = 0;
    for (int i = 0; i < startLine; i++) {
      if (!textPainterHelper.isLineHidden(i)) {
        visualLine++;
      }
    }

    // Get the line text with bounds check
    final line = textPainterHelper.editorState.buffer.lines[startLine];
    final lineWidth = textPainterHelper.measureLineWidth(line);

    // Calculate actual number of lines in the folded region
    final endLine = min(startLine + lineCount,
        textPainterHelper.editorState.buffer.lines.length - 1);

    int foldedLines = 0;

    // Count all lines in the fold range, excluding nested folds
    for (int i = startLine + 1; i <= endLine; i++) {
      // Skip if line index is out of bounds
      if (i >= textPainterHelper.editorState.buffer.lines.length) break;

      bool isInNestedFold = false;
      // Check if this line is part of a different fold
      for (final otherFold in foldedRegions.entries) {
        if (otherFold.key != startLine &&
            otherFold.key < i &&
            i <=
                min(otherFold.value,
                    textPainterHelper.editorState.buffer.lines.length - 1)) {
          isInNestedFold = true;
          break;
        }
      }
      if (!isInNestedFold) {
        foldedLines++;
      }
    }

    // Only draw if there are actually folded lines
    if (foldedLines > 0) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '⋯ $foldedLines',
          style: TextStyle(
            color: editorConfigService.themeService.currentTheme?.textLight ??
                Colors.grey,
            fontSize: editorConfigService.config.fontSize,
            fontStyle: FontStyle.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Constants for padding and positioning
      const horizontalPadding = 8.0;
      final verticalPadding = editorLayoutService.config.lineHeight * 0.1;
      final lineHeight = editorLayoutService.config.lineHeight;

      // Calculate position with improved vertical alignment
      final xPosition = lineWidth + horizontalPadding;
      final yPosition = (visualLine * lineHeight) + verticalPadding / 2;

      // Paint the fold indicator text
      textPainter.paint(
        canvas,
        Offset(xPosition, yPosition),
      );
    }
  }

  @override
  bool shouldRepaint(covariant FoldingPainter oldDelegate) {
    return foldedRegions != oldDelegate.foldedRegions;
  }
}
