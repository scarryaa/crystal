import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter {
  final EditorCore core;
  final int firstVisibleLine;
  final int lastVisibleLine;
  final double viewportHeight;

  double? cachedCharacterWidth;

  late final TextStyle textStyle;
  late final TextPainter textPainter;

  EditorPainter({
    required this.core,
    required this.firstVisibleLine,
    required this.lastVisibleLine,
    required this.viewportHeight,
  }) : super(repaint: core) {
    textStyle = TextStyle(
      color: core.config.textColor,
      fontSize: core.config.fontSize,
      fontFamily: core.config.fontFamily,
      fontWeight: core.config.fontWeight,
      fontFeatures: const [
        FontFeature.enable('kern'),
        FontFeature.enable('liga')
      ],
      decoration: TextDecoration.none,
      decorationColor: Colors.transparent,
    );

    textPainter = TextPainter(
        textDirection: core.config.textDirection ?? TextDirection.ltr);
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawText(canvas);
    drawSelection(canvas);
    drawCurrentLineHighlight(canvas, size);
    drawCursor(canvas);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, viewportHeight),
      Paint()..color = core.config.backgroundColor,
    );
  }

  void drawText(Canvas canvas) {
    textPainter.text = TextSpan(
        text: core.getLines(firstVisibleLine, lastVisibleLine + 5).join('\n'),
        style: textStyle);
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(0, firstVisibleLine * core.config.lineHeight));
  }

  void drawCurrentLineHighlight(Canvas canvas, Size size) {
    if (core.hasSelection()) return;

    canvas.drawRect(
        Rect.fromLTWH(0, core.cursorManager.cursorLine * core.config.lineHeight,
            size.width, core.config.lineHeight),
        Paint()..color = Colors.blue.withOpacity(0.3));
  }

  void drawSelection(Canvas canvas) {
    if (!core.hasSelection()) return;

    final lines = core.getLines(firstVisibleLine, lastVisibleLine + 5);
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      drawSelectionForSingleLine(canvas, i + firstVisibleLine, line);
    }
  }

  void drawSelectionForSingleLine(Canvas canvas, int lineNumber, String line) {
    final int normalizedStartLine =
        min(core.selectionManager.startLine, core.selectionManager.endLine);
    final int normalizedEndLine =
        max(core.selectionManager.startLine, core.selectionManager.endLine);
    final int normalizedStartIndex =
        normalizedStartLine == core.selectionManager.startLine
            ? core.selectionManager.startIndex
            : core.selectionManager.endIndex;
    final int normalizedEndIndex =
        normalizedEndLine == core.selectionManager.endLine
            ? core.selectionManager.endIndex
            : core.selectionManager.startIndex;

    // Check if this line is within selection range
    if (lineNumber >= normalizedStartLine && lineNumber <= normalizedEndLine) {
      final double top = lineNumber * core.config.lineHeight;
      final double height = core.config.lineHeight;
      double left = 0;
      double width = 0;

      // Middle lines
      if (lineNumber > normalizedStartLine && lineNumber < normalizedEndLine) {
        width = (line.length + 1) * core.config.characterWidth;
      }
      // Single line selection
      else if (normalizedStartLine == normalizedEndLine) {
        left = min(normalizedStartIndex, normalizedEndIndex) *
            core.config.characterWidth;
        width = (max(normalizedStartIndex, normalizedEndIndex) -
                min(normalizedStartIndex, normalizedEndIndex)) *
            core.config.characterWidth;
      }
      // Start line
      else if (lineNumber == normalizedStartLine) {
        left = normalizedStartIndex * core.config.characterWidth;
        width = (line.length - normalizedStartIndex + 1) *
            core.config.characterWidth;
      }
      // End line
      else if (lineNumber == normalizedEndLine) {
        left = 0;
        width = normalizedEndIndex * core.config.characterWidth;
      }

      // Show empty line selection indicator
      if (line.isEmpty && normalizedStartLine != normalizedEndLine) {
        if ((lineNumber != core.cursorLine) ||
            (core.selectionManager.startIndex == core.cursorPosition &&
                lineNumber == normalizedStartLine)) {
          left = 0;
          width = core.config.characterWidth;
        }
      }

      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(left, top, width, height),
              Radius.circular(core.config.selectionRadius)),
          Paint()..color = core.config.selectionColor);
    }
  }

  void drawCursor(Canvas canvas) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(
            _measureLineWidth(),
            core.cursorLine * core.config.lineHeight,
            core.config.caretWidth,
            core.config.lineHeight,
          ),
          Radius.circular(core.config.caretRadius)),
      Paint()..color = core.config.caretColor,
    );
  }

  double _measureCharWidth() {
    if (cachedCharacterWidth != null) {
      return cachedCharacterWidth!;
    } else {
      textPainter.text = TextSpan(text: 'w', style: textStyle);
      textPainter.layout();
      cachedCharacterWidth = textPainter.width;
      return cachedCharacterWidth!;
    }
  }

  double _measureLineWidth() {
    return core.cursorPosition * _measureCharWidth();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.firstVisibleLine != firstVisibleLine ||
        oldDelegate.lastVisibleLine != lastVisibleLine ||
        oldDelegate.core.config != core.config ||
        oldDelegate.core.cursorPosition != core.cursorPosition ||
        oldDelegate.textStyle != textStyle;
  }
}
