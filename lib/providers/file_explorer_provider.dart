import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/foundation.dart';

class FileExplorerProvider extends ChangeNotifier {
  final EditorConfigService configService;

  FileExplorerProvider({
    required this.configService,
  }) {
    _isVisible = configService.config.isFileExplorerVisible;
    _isOnLeft = configService.config.isFileExplorerOnLeft;
  }

  bool _isVisible = true;
  bool _isOnLeft = true;

  bool get isVisible => _isVisible;
  bool get isOnLeft => _isOnLeft;

  void toggle() {
    _isVisible = !_isVisible;
    configService.config.isFileExplorerVisible = _isVisible;
    configService.saveConfig();
    notifyListeners();
  }

  void togglePosition() {
    _isOnLeft = !_isOnLeft;
    configService.config.isFileExplorerOnLeft = _isOnLeft;
    configService.saveConfig();
    notifyListeners();
  }

  void setPosition(bool onLeft) {
    if (_isOnLeft != onLeft) {
      _isOnLeft = onLeft;
      configService.config.isFileExplorerOnLeft = onLeft;
      configService.saveConfig();
      notifyListeners();
    }
  }
}
