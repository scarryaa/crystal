import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/services/lsp_service.dart';
import 'package:flutter/material.dart';

class ProjectDiagnosticsManager extends ChangeNotifier {
  final LSPService _lspService;

  ProjectDiagnosticsManager(this._lspService) {
    _lspService.addDiagnosticsListener(_onDiagnosticsChanged);
  }

  void _onDiagnosticsChanged() {
    notifyListeners();
  }

  Map<String, List<Diagnostic>> getAllDiagnostics() {
    return _lspService.getAllDiagnostics();
  }

  List<Diagnostic> getDiagnosticsForFile(String filePath) {
    return _lspService.getDiagnostics(filePath);
  }

  @override
  void dispose() {
    _lspService.removeDiagnosticsListener(_onDiagnosticsChanged);
    super.dispose();
  }
}
