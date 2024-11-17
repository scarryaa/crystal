import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class DiagnosticsPainter {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final EditorState editorState;

  DiagnosticsPainter({
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.editorState,
  });

  void paint(
      Canvas canvas, Size size, int firstVisibleLine, int lastVisibleLine) {
    final diagnostics = editorState.diagnostics;
    final lineHeight = editorLayoutService.config.lineHeight;

    for (var diagnostic in diagnostics) {
      if (diagnostic.range.start.line >= firstVisibleLine &&
          diagnostic.range.start.line <= lastVisibleLine) {
        final startY =
            (diagnostic.range.start.line) * lineHeight + lineHeight + 1;
        final startX = diagnostic.range.start.character *
            editorLayoutService.config.charWidth;
        final endX = (diagnostic.range.end.character -
                diagnostic.range.start.character) *
            editorLayoutService.config.charWidth;

        final paint = Paint()
          ..color = _getDiagnosticColor(diagnostic.severity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

        // Draw squiggly line
        final path = Path();
        path.moveTo(startX, startY);

        const waveLength = 6.0;
        const amplitude = 3.0;

        double x = startX;
        while (x < startX + endX) {
          path.relativeQuadraticBezierTo(
              waveLength / 2, amplitude, waveLength, 0);
          path.relativeQuadraticBezierTo(
              waveLength / 2, -amplitude, waveLength, 0);
          x += waveLength * 2; // Increment by full wave length
        }

        canvas.drawPath(path, paint);
      }
    }
  }

  Color _getDiagnosticColor(DiagnosticSeverity? severity) {
    switch (severity) {
      case DiagnosticSeverity.error:
        return Colors.red;
      case DiagnosticSeverity.warning:
        return Colors.orange;
      case DiagnosticSeverity.information:
        return Colors.blue;
      case DiagnosticSeverity.hint:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
