import 'dart:math';

import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';

class EditorPainterManager {
  EditorViewConfig config;
  EditorPainter? editorPainter;
  double cachedMaxLineWidth = 0;

  EditorPainterManager({
    required this.config,
  });

  void updateCachedMaxLineWidth() {
    cachedMaxLineWidth = maxLineWidth();
  }

  double maxLineWidth() {
    if (editorPainter == null) return 0;

    return config.state.buffer.lines.fold<double>(0, (maxWidth, line) {
      final lineWidth =
          editorPainter == null ? 0.0 : editorPainter!.measureLineWidth(line);
      return max(maxWidth, lineWidth);
    });
  }

  void updateSingleLineWidth(int lineIndex) {
    if (editorPainter == null ||
        lineIndex < 0 ||
        lineIndex >= config.state.buffer.lines.length) {
      return;
    }

    final line = config.state.buffer.lines[lineIndex];
    final lineWidth = editorPainter!.measureLineWidth(line);

    // Only update if this line was previously the longest
    if (lineWidth < cachedMaxLineWidth && isLongestLine(lineIndex)) {
      updateMaxWidthEfficiently();
    } else if (lineWidth > cachedMaxLineWidth) {
      cachedMaxLineWidth = lineWidth;
    }
  }

  bool isLongestLine(int lineIndex) {
    final currentLineWidth =
        editorPainter!.measureLineWidth(config.state.buffer.lines[lineIndex]);
    return currentLineWidth >= cachedMaxLineWidth;
  }

  void updateMaxWidthEfficiently() {
    // Keep track of the longest line index to avoid full recalculation
    double maxWidth = 0;
    for (int i = 0; i < config.state.buffer.lines.length; i++) {
      final lineWidth =
          editorPainter!.measureLineWidth(config.state.buffer.lines[i]);
      maxWidth = max(maxWidth, lineWidth);
    }
    cachedMaxLineWidth = maxWidth;
  }
}
