import 'package:crystal/models/lru_cache.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class TextPainterHelper {
  final TextPainter _textPainter;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final EditorState editorState;
  final _widthCache = LRUCache<String, double>(1000);

  late final TextStyle _baseTextStyle = TextStyle(
    fontFamily: editorConfigService.config.fontFamily,
    fontSize: editorConfigService.config.fontSize,
    height: 1.0,
    leadingDistribution: TextLeadingDistribution.even,
    fontFeatures: const [
      FontFeature.enable('kern'),
      FontFeature.enable('liga'),
    ],
  );

  TextPainterHelper({
    required this.editorSyntaxHighlighter,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.editorState,
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
    final lineHeight = editorLayoutService.config.lineHeight;

    int visualLine = 0;

    // Find first actual visible line
    for (int i = 0; i < firstVisibleLine; i++) {
      if (!isLineHidden(i)) {
        visualLine++;
      }
    }

    // Paint visible lines
    for (int i = firstVisibleLine; i < lastVisibleLine; i++) {
      if (isLineHidden(i)) continue;

      if (i >= 0 && i < lines.length) {
        final line = lines[i];

        editorSyntaxHighlighter.highlight(line);

        _textPainter.text = TextSpan(
          children: [editorSyntaxHighlighter.buildTextSpan(line)],
          style: _baseTextStyle,
        );

        _textPainter.layout(maxWidth: size.width);
        final halfLineHeightDiff = (lineHeight - _textPainter.height) / 2;

        final yPosition = (visualLine * lineHeight) + halfLineHeightDiff;

        _textPainter.paint(
          canvas,
          Offset(0, yPosition),
        );

        visualLine++;
      }
    }
    canvas.restore();
  }

  int getVisibleLineCount(int totalLines) {
    int visibleCount = 0;
    for (int i = 0; i < totalLines; i++) {
      if (!isLineHidden(i)) {
        visibleCount++;
      }
    }
    return visibleCount;
  }

  int getVisualLine(int bufferLine) {
    int visualLine = 0;
    for (int i = 0; i < bufferLine; i++) {
      if (!isLineHidden(i)) {
        visualLine++;
      }
    }
    return visualLine;
  }

  double getVisibleHeight(int totalLines) {
    int visibleCount = 0;
    for (int i = 0; i < totalLines; i++) {
      if (!isLineHidden(i)) {
        visibleCount++;
      }
    }
    return visibleCount * editorLayoutService.config.lineHeight;
  }

  int getNextVisibleLine(int currentLine) {
    int next = currentLine + 1;
    while (next < editorState.buffer.lineCount && isLineHidden(next)) {
      next++;
    }
    return next < editorState.buffer.lineCount ? next : currentLine;
  }

  bool isLineHidden(int line) {
    for (final entry in editorState.foldingState.foldingRanges.entries) {
      if (line > entry.key && line <= entry.value) {
        return true;
      }
    }
    return false;
  }

  double measureLineWidth(String line) {
    final cached = _widthCache.get(line);
    if (cached != null) return cached;

    _textPainter.text = TextSpan(
      text: line,
      style: _baseTextStyle,
    );

    _textPainter.layout();
    final width = _textPainter.width;

    _widthCache.put(line, width);
    return width;
  }
}
