import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';

class TerminalProvider extends ChangeNotifier {
  double _terminalHeight;
  bool _isTerminalVisible;
  final double _minTerminalHeight;
  final double _maxTerminalHeight;
  final EditorConfigService _editorConfigService;

  TerminalProvider({
    required EditorConfigService editorConfigService,
    double initialHeight = 300,
    double minHeight = 100,
    double maxHeight = 800,
    bool initialVisibility = false,
  })  : _editorConfigService = editorConfigService,
        _terminalHeight = initialHeight,
        _minTerminalHeight = minHeight,
        _maxTerminalHeight = maxHeight,
        _isTerminalVisible = initialVisibility {
    initialVisibility = _editorConfigService.config.isTerminalVisible;
    _terminalHeight = _editorConfigService.config.terminalHeight;
  }

  double get terminalHeight => _terminalHeight;
  bool get isTerminalVisible => _isTerminalVisible;
  double get minTerminalHeight => _minTerminalHeight;
  double get maxTerminalHeight => _maxTerminalHeight;

  void updateHeight(double delta) {
    _terminalHeight =
        (_terminalHeight - delta).clamp(_minTerminalHeight, _maxTerminalHeight);
    notifyListeners();
  }

  void saveHeight() {
    _editorConfigService.config.terminalHeight = _terminalHeight;
    _editorConfigService.saveConfig();
  }

  void toggle() {
    setVisibility(!_isTerminalVisible);
  }

  void setVisibility(bool visible) {
    _isTerminalVisible = visible;
    _editorConfigService.config.isTerminalVisible = visible;
    _editorConfigService.saveConfig();
    notifyListeners();
  }
}
