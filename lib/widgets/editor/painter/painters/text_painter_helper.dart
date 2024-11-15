import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class TextPaintingCache {
  final Map<String, TextSpan> _spanCache = {};
  final Map<String, TextPainter> _painterCache = {};
  final Map<String, RegExp> _patternCache = {};
  final int maxSize = 1000;

  // Add line hash cache to avoid recomputing spans for unchanged lines
  final Map<String, int> _lineHashes = {};

  void clear() {
    _spanCache.clear();
    _painterCache.clear();
    _lineHashes.clear();
  }

  TextPainter getPainter(String line, TextStyle baseStyle,
      EditorSyntaxHighlighter highlighter, double maxWidth) {
    final lineHash = line.hashCode;

    // Check if line content hasn't changed
    if (_lineHashes[line] == lineHash && _painterCache.containsKey(line)) {
      return _painterCache[line]!;
    }

    if (_painterCache.length > maxSize) {
      // Use LRU cache eviction instead of removing oldest entries
      final keysToRemove = _painterCache.keys.take(maxSize ~/ 10).toList();
      for (final key in keysToRemove) {
        _painterCache[key]?.dispose(); // Properly dispose painters
        _painterCache.remove(key);
        _spanCache.remove(key);
        _lineHashes.remove(key);
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
      textWidthBasis: TextWidthBasis.longestLine,
    );
    painter.layout(maxWidth: maxWidth);

    _painterCache[line] = painter;
    _lineHashes[line] = lineHash;

    return painter;
  }

  void dispose() {
    for (final painter in _painterCache.values) {
      painter.dispose();
    }
    clear();
  }
}

class TextPainterHelper {
  final TextPainter _textPainter;
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final EditorSyntaxHighlighter editorSyntaxHighlighter;
  final EditorState editorState;
  final TextPaintingCache _paintingCache = TextPaintingCache();

  TextPainterHelper({
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.editorSyntaxHighlighter,
    required this.editorState,
  }) : _textPainter = TextPainter(
          textDirection: TextDirection.ltr,
        );

  TextStyle get _baseStyle => TextStyle(
        fontFamily: editorConfigService.config.fontFamily,
        fontSize: editorConfigService.config.fontSize,
        height: editorLayoutService.config.lineHeight /
            editorConfigService.config.fontSize,
      );

  void paintText(Canvas canvas, Size size, int firstVisibleLine,
      int lastVisibleLine, List<String> lines) {
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

      // Use the cache instead of direct highlighting
      final painter = _paintingCache.getPainter(
          line, _baseStyle, editorSyntaxHighlighter, size.width);

      final halfLineHeightDiff = (lineHeight - painter.height) / 2;
      final yPosition = (visualLine * lineHeight) + halfLineHeightDiff;

      painter.paint(
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
