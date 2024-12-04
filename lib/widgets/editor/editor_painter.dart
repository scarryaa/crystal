import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class EditorPainter extends CustomPainter with ChangeNotifier {
  final EditorCore core;
  final int firstVisibleLine;
  final int lastVisibleLine;

  late final TextStyle textStyle;
  final TextPainter textPainter = TextPainter(textDirection: TextDirection.ltr);

  EditorPainter({
    required this.core,
    required this.firstVisibleLine,
    required this.lastVisibleLine,
  }) : super(repaint: core) {
    textStyle = TextStyle(
      color: core.config.textColor,
      fontSize: core.config.fontSize,
      fontFamily: core.config.fontFamily,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    drawBackground(canvas, size);
    drawText(canvas);
    drawSelection(canvas);
    drawCursor(canvas);
  }

  void drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = core.config.backgroundColor,
    );
  }

  void drawText(Canvas canvas) {
    textPainter.text = TextSpan(
        text: core.getLines(firstVisibleLine, lastVisibleLine).join('\n'),
        style: textStyle);
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(0, firstVisibleLine * core.config.lineHeight));
  }

  void drawSelection(Canvas canvas) {
    if (!core.hasSelection()) return;

    var lines = core.getLines(firstVisibleLine, lastVisibleLine);
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      drawSelectionForSingleLine(canvas, i, line);
    }
  }

  void drawSelectionForSingleLine(Canvas canvas, int lineNumber, String line) {
    int normalizedStartLine =
        min(core.selectionManager.startLine, core.selectionManager.endLine);
    int normalizedEndLine =
        max(core.selectionManager.startLine, core.selectionManager.endLine);
    int normalizedStartIndex =
        normalizedStartLine == core.selectionManager.startLine
            ? core.selectionManager.startIndex
            : core.selectionManager.endIndex;
    int normalizedEndIndex = normalizedEndLine == core.selectionManager.endLine
        ? core.selectionManager.endIndex
        : core.selectionManager.startIndex;

    // Check if this line is within selection range
    if (lineNumber >= normalizedStartLine && lineNumber <= normalizedEndLine) {
      double top = lineNumber * core.config.lineHeight;
      double height = core.config.lineHeight;
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
              const Radius.circular(2.0)),
          Paint()..color = Colors.blue.withOpacity(0.3));
    }
  }

  void drawCursor(Canvas canvas) {
    canvas.drawRect(
      Rect.fromLTWH(
        _measureLineWidth(),
        core.cursorLine * core.config.lineHeight,
        core.config.caretWidth,
        core.config.lineHeight,
      ),
      Paint()..color = core.config.caretColor,
    );
  }

  double _measureCharWidth() {
    textPainter.text = TextSpan(text: 'w', style: textStyle);
    textPainter.layout();
    return textPainter.width;
  }

  double _measureLineWidth() {
    return core.cursorPosition * _measureCharWidth();
  }

  @override
  bool shouldRepaint(covariant EditorPainter oldDelegate) {
    return oldDelegate.core.lines != core.lines ||
        oldDelegate.core.config != core.config ||
        oldDelegate.textStyle != textStyle;
  }
}
