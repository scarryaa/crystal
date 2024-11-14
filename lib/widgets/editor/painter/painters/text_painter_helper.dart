import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class TextPaintingCache {
  final Map<String, TextSpan> _spanCache = {};
  final Map<String, TextPainter> _painterCache = {};
  final int maxSize = 1000; // Adjust based on memory constraints

  void clear() {
    _spanCache.clear();
    _painterCache.clear();
  }

  TextPainter getPainter(String line, TextStyle baseStyle,
      EditorSyntaxHighlighter highlighter, double maxWidth) {
    if (!_painterCache.containsKey(line)) {
      if (_painterCache.length > maxSize) {
        // Remove oldest entries when cache is full
        final keysToRemove = _painterCache.keys.take(maxSize ~/ 4).toList();
        for (final key in keysToRemove) {
          _painterCache.remove(key);
          _spanCache.remove(key);
        }
      }

      TextSpan span = _spanCache.putIfAbsent(line, () {
        highlighter.highlight(line);
        return TextSpan(
          children: [highlighter.buildTextSpan(line)],
          style: baseStyle,
        );
      });

      final painter = TextPainter(
        text: span,
        textDirection: TextDirection.ltr,
      );
      painter.layout();
      _painterCache[line] = painter;
    }

    return _painterCache[line]!;
  }
}

class TextPainterHelper {
  final TextPainter _textPainter;
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final EditorState editorState;

  TextPainterHelper({
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.editorSyntaxHighlighter,
    required this.editorState,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
        );

  void paintText(
    Canvas canvas,
    Size size,
    int firstVisibleLine,
    int lastVisibleLine,
    List<String> lines,
  ) {
    canvas.save();
    final lineHeight = editorLayoutService.config.lineHeight;
    int visualLine = 0;
    const bufferLines = 5;

    // Find the first actual line to start painting
    int startLine = 0;
    while (startLine < lines.length &&
        visualLine < firstVisibleLine - bufferLines) {
      if (!editorState.isLineHidden(startLine)) {
        visualLine++;
      }
      startLine++;
    }

    visualLine = max(0, firstVisibleLine - bufferLines);

    for (int i = startLine; i < lines.length; i++) {
      if (editorState.isLineHidden(i)) continue;

      final line = lines[i];

      editorSyntaxHighlighter.highlight(line);

      _textPainter.text = TextSpan(
        children: [editorSyntaxHighlighter.buildTextSpan(line)],
        style: TextStyle(
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          height: editorLayoutService.config.lineHeight /
              editorConfigService.config.fontSize,
        ),
      );

      _textPainter.layout();
      final halfLineHeightDiff = (lineHeight - _textPainter.height) / 2;

      final yPosition = (visualLine * lineHeight) + halfLineHeightDiff;

      _textPainter.paint(
        canvas,
        Offset(0, yPosition),
      );

      visualLine++;

      if (visualLine > lastVisibleLine + bufferLines) break;
    }

    canvas.restore();
  }

  double measureLineWidth(String line) {
    _textPainter.text = TextSpan(
      text: line,
      style: TextStyle(
        fontFamily: editorConfigService.config.fontFamily,
        fontSize: editorConfigService.config.fontSize,
        height: editorLayoutService.config.lineHeight /
            editorConfigService.config.fontSize,
      ),
    );
    _textPainter.layout();
    return _textPainter.width;
  }

  bool isLineHidden(int line) {
    return editorState.isLineHidden(line);
  }

  void dispose() {
    _textPainter.dispose();
  }
}
