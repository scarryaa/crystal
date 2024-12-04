import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/selection/direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorInputManager {
  KeyEventResult handleKeyEvent(EditorCore core, KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isMetaOrCtrlPressed =
        HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;

    if (handleCtrlKeys(core, keyEvent, isMetaOrCtrlPressed)) {
      return KeyEventResult.handled;
    }

    if (handleArrowKeys(core, keyEvent, isShiftPressed)) {
      return KeyEventResult.handled;
    }

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

  bool handleArrowKeys(
      EditorCore core, KeyEvent keyEvent, bool isShiftPressed) {
    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.arrowLeft:
        _handleSelection(core, isShiftPressed, SelectionDirection.backward);
        core.moveLeft();
        return true;
      case LogicalKeyboardKey.arrowRight:
        _handleSelection(core, isShiftPressed, SelectionDirection.forward);
        core.moveRight();
        return true;
      case LogicalKeyboardKey.arrowUp:
        _handleSelection(core, isShiftPressed, SelectionDirection.previousLine);
        core.moveUp();
        return true;
      case LogicalKeyboardKey.arrowDown:
        _handleSelection(core, isShiftPressed, SelectionDirection.nextLine);
        core.moveDown();
        return true;
      default:
        return false;
    }
  }

  bool handleCtrlKeys(
      EditorCore core, KeyEvent keyEvent, bool isMetaOrCtrlPressed) {
    if (!isMetaOrCtrlPressed) return false;

    switch (keyEvent) {
      case LogicalKeyboardKey.keyC:
        return true;
      case LogicalKeyboardKey.keyV:
        return true;
      case LogicalKeyboardKey.keyX:
        return true;
      default:
        return false;
    }
  }

  void _handleSelection(
      EditorCore core, bool isShiftPressed, SelectionDirection direction) {
    if (isShiftPressed) {
      core.handleSelection(direction);
    } else {
      core.clearSelection();
    }
  }
}
