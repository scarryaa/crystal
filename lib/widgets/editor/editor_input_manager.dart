import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorInputManager {
  KeyEventResult handleKeyEvent(EditorCore core, KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (handleArrowKeys(core, keyEvent)) return KeyEventResult.handled;

    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.enter:
        core.insertLine();
        break;
      case LogicalKeyboardKey.backspace:
        core.delete(1);
        break;
      case LogicalKeyboardKey.delete:
        core.deleteForwards(1);
      default:
        if (keyEvent.character == null) return KeyEventResult.ignored;

        core.insertChar(keyEvent.character!);
        break;
    }

    return KeyEventResult.handled;
  }

  bool handleArrowKeys(EditorCore core, KeyEvent keyEvent) {
    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        core.moveLeft();
        return true;
      case LogicalKeyboardKey.arrowRight:
        core.moveRight();
        return true;
      case LogicalKeyboardKey.arrowUp:
        core.moveUp();
        return true;
      case LogicalKeyboardKey.arrowDown:
        core.moveDown();
        return true;
      default:
        return false;
    }
  }
}
