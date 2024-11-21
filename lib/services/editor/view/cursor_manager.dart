import 'dart:async';

import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/services/editor/view/hover_manager.dart';

class CursorManager {
  final EditorViewConfig config;
  final HoverManager hoverManager;
  Position? _lastCursorPosition;
  Timer? _cursorMoveTimer;
  bool isCursorMovementRecent = false;

  CursorManager(this.config, this.hoverManager);

  void handleCursorMove() {
    if (config.state.cursors.isEmpty) return;

    final currentCursor = config.state.cursors.first;
    final currentPosition = Position(
      line: currentCursor.line,
      column: currentCursor.column,
    );

    if (_lastCursorPosition != currentPosition) {
      _lastCursorPosition = currentPosition;
      isCursorMovementRecent = true;
      hoverManager.cancelHoverOperations();

      // Reset the cursor movement flag after a short delay
      _cursorMoveTimer?.cancel();
      _cursorMoveTimer = Timer(const Duration(milliseconds: 300), () {
        isCursorMovementRecent = false;
      });
    }
  }

  void dispose() {
    _cursorMoveTimer?.cancel();
  }
}
