import 'package:flutter/material.dart';

class PopupState extends ChangeNotifier {
  bool _showHoverInfoPopup = false;
  bool _showDiagnosticsPopup = false;
  bool _isHoveringInfoPopup = false;
  bool _isHoveringDiagnosticsPopup = false;

  bool get showHoverInfoPopup => _showHoverInfoPopup;
  bool get showDiagnosticsPopup => _showDiagnosticsPopup;
  bool get isHoveringInfoPopup => _isHoveringInfoPopup;
  bool get isHoveringDiagnosticsPopup => _isHoveringDiagnosticsPopup;

  void setShowHoverInfoPopup(bool value) {
    _showHoverInfoPopup = value;
    notifyListeners();
  }

  void setShowDiagnosticsPopup(bool value) {
    _showDiagnosticsPopup = value;
    notifyListeners();
  }

  void setIsHoveringInfoPopup(bool value) {
    _isHoveringInfoPopup = value;
    notifyListeners();
  }

  void setIsHoveringDiagnosticsPopup(bool value) {
    _isHoveringDiagnosticsPopup = value;
    notifyListeners();
  }
}
