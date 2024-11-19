import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:flutter/material.dart' hide TextRange;

class HoverDiagnosticsPainter {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;

  HoverDiagnosticsPainter({
    required this.editorConfigService,
    required this.editorLayoutService,
  });

  void paint(
    Canvas canvas,
    TextRange? hoveredWordRange,
    List<Diagnostic>? hoveredInfo,
  ) {
    if (hoveredWordRange == null ||
        hoveredInfo == null ||
        hoveredInfo.isEmpty) {
      return;
    }

    final theme = editorConfigService.themeService.currentTheme;
    if (theme == null) return;

    final paint = Paint()
      ..color = theme.error // or appropriate color based on diagnostic severity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final startOffset =
        editorLayoutService.getOffsetForPosition(hoveredWordRange.start);
    final endOffset =
        editorLayoutService.getOffsetForPosition(hoveredWordRange.end);

    // Draw underline
    final y = startOffset.dy + editorLayoutService.config.lineHeight - 2;
    canvas.drawLine(
      Offset(startOffset.dx, y),
      Offset(endOffset.dx, y),
      paint,
    );
  }
}
