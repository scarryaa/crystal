import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:logging/logging.dart';

class DiagnosticsManager {
  final Map<String, List<Diagnostic>> _fileDiagnostics = {};
  final List<Function()> _diagnosticsListeners = [];
  final _logger = Logger('DiagnosticsManager');
  final EditorState _editor;

  DiagnosticsManager(this._editor);

  void handleDiagnostics(Map<String, dynamic> params) {
    try {
      final uri = params['uri'] as String?;
      if (uri == null || uri.isEmpty) {
        _logger.warning('Received diagnostics with empty URI');
        return;
      }

      final diagnosticsList = params['diagnostics'] as List?;
      if (diagnosticsList == null) {
        _logger.warning('Received diagnostics without diagnostics list');
        return;
      }

      final diagnostics = diagnosticsList
          .map((d) => Diagnostic.fromJson(d as Map<String, dynamic>))
          .toList();

      final filePath = Uri.parse(uri).toFilePath();
      updateDiagnostics(filePath, diagnostics);
    } catch (e, stack) {
      _logger.severe('Error handling diagnostics', e, stack);
    }
  }

  void updateDiagnostics(String filePath, List<Diagnostic> diagnostics) {
    _fileDiagnostics[filePath] = diagnostics;

    if (filePath == _editor.path) {
      _editor.updateDiagnostics(diagnostics);
    }

    notifyListeners();
  }

  void addListener(Function() listener) {
    _diagnosticsListeners.add(listener);
  }

  void removeListener(Function() listener) {
    _diagnosticsListeners.remove(listener);
  }

  void notifyListeners() {
    for (var listener in _diagnosticsListeners) {
      listener();
    }
  }

  List<Diagnostic> getDiagnostics(String filePath) {
    return _fileDiagnostics[filePath] ?? [];
  }

  Map<String, List<Diagnostic>> getAllDiagnostics() {
    return Map.from(_fileDiagnostics);
  }
}
