import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:crystal/widgets/editor/managers/editor_mouse_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorInputManager {
  final EditorCore core;
  late EditorMouseManager mouseManager;

  EditorInputManager(this.core) {
    mouseManager = EditorMouseManager(core);
  }

  void handleMouseEvent(
      Offset localPosition, Offset scrollPosition, PointerEvent event) {
    mouseManager.handleMouseEvent(event, localPosition, scrollPosition);
  }

  Future<KeyEventResult> handleKeyEvent(
      EditorCore core, KeyEvent keyEvent) async {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isMetaOrCtrlPressed =
        HardwareKeyboard.instance.isControlPressed ||
            HardwareKeyboard.instance.isMetaPressed;

    if (await handleCtrlKeys(core, keyEvent, isMetaOrCtrlPressed)) {
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
      case LogicalKeyboardKey.tab:
        if (isShiftPressed) {
          // TODO
          return KeyEventResult.handled;
        }

        core.insertChar('    ');
        for (int i = 0; i < core.cursorManager.cursors.length; i++) {
          core.moveCursorTo(i, core.cursorManager.cursors[i].line,
              core.cursorManager.cursors[i].index + 3);
        }
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

  Future<bool> handleCtrlKeys(
      EditorCore core, KeyEvent keyEvent, bool isMetaOrCtrlPressed) async {
    if (!isMetaOrCtrlPressed) return false;

    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.keyA:
        core.selectAll();
        return true;
      case LogicalKeyboardKey.keyC:
        core.copy();
        return true;
      case LogicalKeyboardKey.keyV:
        await core.paste();
        return true;
      case LogicalKeyboardKey.keyX:
        core.cut();
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
