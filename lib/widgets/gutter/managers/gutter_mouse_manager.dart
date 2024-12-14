import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/mouse/mouse_button_type.dart';
import 'package:crystal/widgets/editor/managers/editor_mouse_manager.dart';
import 'package:flutter/material.dart';

class GutterMouseManager {
  EditorCore core;

  bool _isDragging = false;
  (int, int)? _dragStartPosition;

  GutterMouseManager(this.core);

  void handleMouseEvent(
      PointerEvent event, Offset localPosition, Offset scrollPosition) {
    if (event is PointerDownEvent) {
      _handlePointerDown(
          event, localPosition, scrollPosition, MouseButtonType.left);
    } else if (event is PointerMoveEvent) {
      _handlePointerMove(event, localPosition, scrollPosition);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event, localPosition, scrollPosition);
    }
  }

  void _handlePointerDown(PointerDownEvent event, Offset localPosition,
      Offset scrollPosition, MouseButtonType mouseButton) {
    final textPosition =
        _convertPositionToTextIndex(localPosition, scrollPosition);

    switch (mouseButton) {
      case MouseButtonType.left:
        _handleSingleClick(textPosition.$1, textPosition.$2);
        _isDragging = true;
        _dragStartPosition = textPosition;
        break;
      default:
      // Do nothing
    }
  }

  void _handleSingleClick(int cursorLine, int cursorIndex) {
    core.cursorManager.clearCursors(keepAnchor: false);
    core.clearSelection();
    core.selectLine(cursorLine, cursorIndex);
    core.addCursor(min(cursorLine + 1, core.bufferManager.lineCount - 1), 0);
  }

  (int, int) _convertPositionToTextIndex(
      Offset localPosition, Offset scrollPosition) {
    return (
      (localPosition.dy) ~/ core.config.lineHeight,
      (localPosition.dx + scrollPosition.dx) ~/ core.config.characterWidth
    );
  }

  void _handlePointerMove(
      PointerMoveEvent event, Offset localPosition, Offset scrollPosition) {
    if (_isDragging) {
      core.cursorManager.clearCursors(keepAnchor: false);
      final currentPosition =
          _convertPositionToTextIndex(localPosition, scrollPosition);

      if (_dragStartPosition != null) {
        core.selectionManager.clearSelections(0);
        core.selectRange(_dragStartPosition!.$1, 0, currentPosition.$1 + 1, 0);
        if (_dragStartPosition!.$1 > currentPosition.$1) {
          core.selectLine(_dragStartPosition!.$1, 0);
        }

        core.addCursor(
            min(max(currentPosition.$1 + 1, 0),
                core.bufferManager.lineCount - 1),
            0);
      }
    }
  }

  void _handlePointerUp(
      PointerUpEvent event, Offset localPosition, Offset scrollPosition) {
    _isDragging = false;
    _dragStartPosition = null;
  }
}
