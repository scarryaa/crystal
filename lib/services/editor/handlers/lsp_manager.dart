import 'dart:async';

import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/lsp_service.dart';

class LSPManager {
  final LSPService lspService;
  final Buffer buffer;
  final Function(String) tapCallback;
  final Function(int, int) setCursor;
  final Function(int) scrollToLine;
  final Function() notifyListeners;

  List<lsp_models.Diagnostic> diagnostics = [];
  bool isHoverInfoVisible = false;
  Position? _lastHoverPosition;
  Timer? _hoverTimer;
  bool _isHoveringPopup = false;

  LSPManager({
    required this.lspService,
    required this.buffer,
    required this.tapCallback,
    required this.setCursor,
    required this.scrollToLine,
    required this.notifyListeners,
  });

  void setIsHoveringPopup(bool isHovering) {
    _isHoveringPopup = isHovering;
  }

  void updateDiagnostics(List<lsp_models.Diagnostic> newDiagnostics) {
    diagnostics = newDiagnostics;
    notifyListeners();
  }

  Future<void> showHover(int line, int character) async {
    final currentPosition = Position(line: line, column: character);

    if (_lastHoverPosition != currentPosition) {
      _hoverTimer?.cancel();
      _lastHoverPosition = currentPosition;

      // Always fetch diagnostics and hover information
      await showDiagnostics(line, character);
      final response = await lspService.getHover(line, character);

      String content = '';
      if (response != null) {
        content = response['contents']?['value'] ?? '';
      }

      final matchingDiagnostics = _getDiagnosticsForPosition(line, character);
      final rustContent = _processRustDiagnostics(matchingDiagnostics);

      if (rustContent.isNotEmpty) {
        content = content.isEmpty ? rustContent : '$content\n\n$rustContent';
      }

      if (content.isNotEmpty) {
        _emitHoverEvent(line, character, content, matchingDiagnostics);
      }
    }
  }

  Future<List<lsp_models.Diagnostic>?> showDiagnostics(
      int line, int character) async {
    final matchingDiagnostics = _getDiagnosticsForPosition(line, character);
    _emitHoverEvent(line, character, '', matchingDiagnostics);
    return matchingDiagnostics.isEmpty ? null : matchingDiagnostics;
  }

  Future<void> goToDefinition(int line, int character) async {
    final response = await lspService.getDefinition(line, character);

    if (response != null) {
      final location = response['uri'];
      if (location != null) {
        final path = location.toString().replaceFirst('file://', '');
        await tapCallback(path);

        if (response['range'] != null) {
          final targetLine = response['range']['start']['line'];
          final targetCharacter = response['range']['start']['character'];
          setCursor(targetLine, targetCharacter);
          scrollToLine(targetLine);
        }
      }
    }
  }

  List<lsp_models.Diagnostic> _getDiagnosticsForPosition(
      int line, int character) {
    return diagnostics.where((diagnostic) {
      final range = diagnostic.range;
      return line >= range.start.line &&
          line <= range.end.line &&
          character >= range.start.character - 1 &&
          character <= range.end.character + 1;
    }).toList();
  }

  String _processRustDiagnostics(List<lsp_models.Diagnostic> diagnostics) {
    final rustDiagnostics = diagnostics
        .where((d) =>
            d.source.toLowerCase() == 'rust-analyzer' ||
            d.source.toLowerCase() == 'rustc')
        .toList();
    return rustDiagnostics.isNotEmpty
        ? formatRustDiagnostics(rustDiagnostics)
        : '';
  }

  String formatRustDiagnostics(List<lsp_models.Diagnostic> diagnostics) {
    final buffer = StringBuffer();
    buffer.writeln('```rust-analyzer');

    for (final diagnostic in diagnostics) {
      final startLine = diagnostic.range.start.line + 1;
      final startChar = diagnostic.range.start.character + 1;
      final location = 'line $startLine, column $startChar';
      final severity = getSeverityLabel(diagnostic.severity);

      buffer.writeln('$severity[$location]: ${diagnostic.message}');
      if (diagnostic.code != null) {
        buffer.writeln('Code: ${diagnostic.code}');
      }
      buffer.writeln('Source: ${diagnostic.source}');
      if (diagnostic.codeDescription?.href != null) {
        buffer.writeln('Documentation: ${diagnostic.codeDescription!.href}');
      }
      buffer.writeln();
    }

    buffer.writeln('```');
    return buffer.toString();
  }

  String getSeverityLabel(lsp_models.DiagnosticSeverity severity) {
    final severityValue = severity.index + 1;
    switch (severityValue) {
      case 1:
        return 'error';
      case 2:
        return 'warning';
      case 3:
        return 'info';
      case 4:
        return 'hint';
      default:
        return 'unknown';
    }
  }

  void _emitHoverEvent(int line, int character, String content,
      List<lsp_models.Diagnostic> diagnostics) {
    TextRange? diagnosticRange;

    if (diagnostics.isNotEmpty) {
      final closestDiagnostic = diagnostics.reduce((a, b) {
        final aSize = (a.range.end.character - a.range.start.character) +
            (a.range.end.line - a.range.start.line) * 1000;
        final bSize = (b.range.end.character - b.range.start.character) +
            (b.range.end.line - b.range.start.line) * 1000;
        return aSize < bSize ? a : b;
      });

      diagnosticRange = TextRange(
        start: Position(
            line: closestDiagnostic.range.start.line,
            column: closestDiagnostic.range.start.character),
        end: Position(
            line: closestDiagnostic.range.end.line,
            column: closestDiagnostic.range.end.character),
      );
    }

    EditorEventBus.emit(HoverEvent(
      content: content,
      line: line,
      character: character,
      diagnostics: diagnostics,
      diagnosticRange: diagnosticRange,
    ));
  }
}
