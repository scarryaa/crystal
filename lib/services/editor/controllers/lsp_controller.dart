import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/models/server_command.dart';
import 'package:crystal/services/editor/handlers/lsp_manager.dart';
import 'package:crystal/services/lsp_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

class LSPController {
  final LSPService _service;
  late final LSPManager _manager;
  final EditorState _editor;

  final Logger _logger = Logger('LSPController');

  ValueNotifier<bool> get isRunningNotifier => _service.isRunningNotifier;
  ValueNotifier<String> get statusMessageNotifier =>
      _service.statusMessageNotifier;
  ValueNotifier<bool> get isInitializingNotifier =>
      _service.isInitializingNotifier;
  ValueNotifier<bool> get workProgressNotifier => _service.workProgressNotifier;
  ValueNotifier<String> get workProgressMessage => _service.workProgressMessage;

  List<Diagnostic> get diagnostics => _manager.diagnostics;

  LSPController(EditorState editor)
      : _editor = editor,
        _service = LSPService(editor) {
    _manager = LSPManager(
      lspService: _service,
      buffer: editor.buffer,
      tapCallback: editor.openFile,
      setCursor: editor.setCursor,
      scrollToLine: editor.scrollToLine,
      notifyListeners: editor.notifyListeners,
    );
  }

  // Initialization and lifecycle
  Future<void> initialize() async {
    await _service.initialize();
    _service.addDiagnosticsListener(() {
      _manager.updateDiagnostics(_service.getDiagnostics(_editor.path));
    });
  }

  void dispose() {
    _service.dispose();
  }

  // Document management
  Future<void> sendDidOpenNotification(String text) async {
    try {
      await _service.sendDidOpenNotification(text);
    } catch (e, stackTrace) {
      _logger.warning('Error sending open notification', e, stackTrace);
      // Consider showing an error to the user or handling it differently
    }
  }

  Future<void> sendDidChangeNotification(String text) async {
    try {
      await _service.sendDidChangeNotification(text);
    } catch (e, stackTrace) {
      _logger.warning('Error sending change notification', e, stackTrace);
    }
  }

  // LSP features
  Future<void> showHover(int line, int character) async {
    await _manager.showHover(line, character);
  }

  Future<void> goToDefinition(int line, int character) async {
    await _manager.goToDefinition(line, character);
  }

  Future<Map<String, dynamic>?> getCompletion(int line, int character) async {
    return _service.getCompletion(line, character);
  }

  // Diagnostics management
  void updateDiagnostics(List<Diagnostic> newDiagnostics) {
    _manager.updateDiagnostics(newDiagnostics);
  }

  List<Diagnostic> getDiagnostics(String filePath) {
    return _service.getDiagnostics(filePath);
  }

  Map<String, List<Diagnostic>> getAllDiagnostics() {
    return _service.getAllDiagnostics();
  }

  String formatRustDiagnostics() => _manager.formatRustDiagnostics(diagnostics);

  String getSeverityLabel(DiagnosticSeverity diagnosticSeverity) =>
      _manager.getSeverityLabel(diagnosticSeverity);

  // Server status
  bool isLanguageServerRunning() {
    return _service.isLanguageServerRunning();
  }

  bool isAnalysisStuck() {
    return _service.isAnalysisStuck();
  }

  // Hover management
  void setIsHoveringPopup(bool isHovering) {
    _manager.setIsHoveringPopup(isHovering);
  }

  Future<List<Diagnostic>?> showDiagnostics(int line, int character) async {
    return _manager.showDiagnostics(line, character);
  }

  // Server information
  String? get currentServerName => _service.currentServerName;
  ServerCommand? get currentServerCommand => _service.currentServerCommand;

  // Event listeners
  void addDiagnosticsListener(Function() listener) {
    _service.addDiagnosticsListener(listener);
  }

  void removeDiagnosticsListener(Function() listener) {
    _service.removeDiagnosticsListener(listener);
  }
}
