import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class TextPainterHelper {
  final TextPainter _textPainter;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  TextPainterHelper({
    required this.editorSyntaxHighlighter,
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
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

  void paintText(Canvas canvas, Size size, int firstVisibleLine,
      int lastVisibleLine, List<String> lines) {
    canvas.save();
    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i >= 0 && i < lines.length) {
        String line = lines[i];

        editorSyntaxHighlighter.highlight(line);

        _textPainter.text = editorSyntaxHighlighter.buildTextSpan(line);
        _textPainter.layout(maxWidth: size.width);

        double yPosition = (i * editorLayoutService.config.lineHeight) +
            (editorLayoutService.config.lineHeight - _textPainter.height) / 2;

        _textPainter.paint(canvas, Offset(0, yPosition));
      }
    }
    canvas.restore();
  }

  double measureLineWidth(String line) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          fontWeight: FontWeight.normal,
          height: 1.0,
          leadingDistribution: TextLeadingDistribution.even,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    textPainter.layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.width;
  }
}
