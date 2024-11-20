import 'dart:async';

import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';

class HoverState {
  Position? lastHoverPosition;
  Timer? hoverTimer;
  List<lsp_models.Diagnostic> diagnostics = [];
  bool isHoveringPopup = false;

  void updateHoverPosition(Position position) {
    lastHoverPosition = position;
  }
}
