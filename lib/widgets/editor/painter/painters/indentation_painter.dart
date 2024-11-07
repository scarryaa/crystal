import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class IndentationPainter extends EditorPainterBase {
  final EditorState editorState;
  final double viewportHeight;

  IndentationPainter({
    required this.editorState,
    required this.viewportHeight,
    required super.editorLayoutService,
    required super.editorConfigService,
  });

  @override
  void paint(Canvas canvas, Size size,
      {required int firstVisibleLine, required int lastVisibleLine}) {
    final lines = editorState.buffer.lines;

    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i >= 0 && i < lines.length) {
        final line = lines[i];
        final leadingSpaces = _countLeadingSpaces(line);

        for (int space = 0; space < leadingSpaces; space += 4) {
          if (line.isNotEmpty && !line.startsWith(' ')) continue;
          final xPosition = space * editorLayoutService.config.charWidth;
          _drawIndentLine(canvas, xPosition, i);
        }
      }
    }
  }

  void _drawIndentLine(Canvas canvas, double left, int lineNumber) {
    const double lineOffset = 1;

    canvas.drawLine(
        Offset(left + lineOffset,
            lineNumber * editorLayoutService.config.lineHeight),
        Offset(
            left + lineOffset,
            lineNumber * editorLayoutService.config.lineHeight +
                editorLayoutService.config.lineHeight),
        Paint()
          ..color =
              editorConfigService.themeService.currentTheme.indentLineColor);
  }

  int _countLeadingSpaces(String line) {
    int count = 0;
    for (int j = 0; j < line.length; j++) {
      if (line[j] == ' ') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  @override
  bool shouldRepaint(covariant IndentationPainter oldDelegate) {
    return editorState.buffer.version != oldDelegate.editorState.buffer.version;
  }
}
