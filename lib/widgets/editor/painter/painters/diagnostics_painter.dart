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
        _paintDiagnostic(canvas, diagnostic, lineHeight);

        // Paint related information if available
        if (diagnostic.relatedInformation != null) {
          for (var related in diagnostic.relatedInformation!) {
            _paintRelatedInformation(canvas, related, lineHeight);
          }
        }
      }
    }
  }

  void _paintDiagnostic(
      Canvas canvas, Diagnostic diagnostic, double lineHeight) {
    final startY = (diagnostic.range.start.line) * lineHeight + lineHeight + 1;
    final startX =
        diagnostic.range.start.character * editorLayoutService.config.charWidth;
    final endX =
        diagnostic.range.end.character * editorLayoutService.config.charWidth;

    final paint = Paint()
      ..color = _getDiagnosticColor(diagnostic.severity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Check if the diagnostic has zero width
    if (startX == endX) {
      // For zero-width diagnostics, offset back by one character width
      final adjustedStartX = startX - editorLayoutService.config.charWidth;
      _drawSquigglyLine(canvas, adjustedStartX, startY,
          editorLayoutService.config.charWidth, paint);
    } else {
      // For non-zero width diagnostics, draw the squiggly line as normal
      _drawSquigglyLine(canvas, startX, startY, endX - startX, paint);
    }
  }

  void _paintRelatedInformation(
      Canvas canvas, DiagnosticRelatedInformation related, double lineHeight) {
    final startY =
        (related.location.range.start.line) * lineHeight + lineHeight + 1;
    final startX = related.location.range.start.character *
        editorLayoutService.config.charWidth;
    final endX = related.location.range.end.character *
        editorLayoutService.config.charWidth;

    final paint = Paint()
      ..color = Colors.blue.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    if (startX == endX) {
      // For zero-width related information, extend by 1 character width on each side
      final extendedStartX = startX - editorLayoutService.config.charWidth;
      final extendedEndX = endX + editorLayoutService.config.charWidth;
      _drawSquigglyLine(
          canvas, extendedStartX, startY, extendedEndX - extendedStartX, paint);
    } else {
      // For non-zero width related information, draw the squiggly line as normal
      _drawSquigglyLine(canvas, startX, startY, endX - startX, paint);
    }
  }

  void _drawSquigglyLine(
      Canvas canvas, double startX, double startY, double width, Paint paint) {
    final path = Path();
    path.moveTo(startX, startY);

    const waveLength = 6.0;
    const amplitude = 3.0;

    double x = startX;
    while (x < startX + width) {
      path.relativeQuadraticBezierTo(waveLength / 2, amplitude, waveLength, 0);
      path.relativeQuadraticBezierTo(waveLength / 2, -amplitude, waveLength, 0);
      x += waveLength * 2;
    }

    canvas.drawPath(path, paint);
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
