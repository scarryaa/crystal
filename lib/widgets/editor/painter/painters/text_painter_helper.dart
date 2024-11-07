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
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          strutStyle: StrutStyle(
            fontSize: editorConfigService.config.fontSize,
            fontFamily: editorConfigService.config.fontFamily,
            height: 1.0,
            forceStrutHeight: true,
          ),
        );

  void paintText(Canvas canvas, Size size, int firstVisibleLine,
      int lastVisibleLine, List<String> lines) {
    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (i >= 0 && i < lines.length) {
        String line = lines[i];

        // Highlight the current line's syntax
        editorSyntaxHighlighter.highlight(line);

        // Create text painter with highlighted spans
        _textPainter.text = editorSyntaxHighlighter.buildTextSpan(line);
        _textPainter.layout();

        double yPosition = (i * editorLayoutService.config.lineHeight) +
            (editorLayoutService.config.lineHeight - _textPainter.height) / 2;

        _textPainter.paint(canvas, Offset(0, yPosition));
      }
    }
  }

  double measureLineWidth(String line) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: line,
        style: TextStyle(
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          fontWeight: FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.width;
  }
}
