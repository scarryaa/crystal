import 'dart:io';
import 'dart:math';

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
    final bool isMetaOrCtrlPressed = Platform.isMacOS
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    if (await handleCtrlKeys(core, keyEvent, isMetaOrCtrlPressed)) {
      return KeyEventResult.handled;
    }

    if (handleArrowKeys(
        core, keyEvent, isShiftPressed, isMetaOrCtrlPressed, isAltPressed)) {
      return KeyEventResult.handled;
    }

    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.escape:
        core.cursorManager.clearCursors();
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

  bool handleArrowKeys(EditorCore core, KeyEvent keyEvent, bool isShiftPressed,
      bool isMetaOrCtrlPressed, bool isAltPressed) {
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
      case LogicalKeyboardKey.arrowDown:
        final isUpArrow = keyEvent.logicalKey == LogicalKeyboardKey.arrowUp;
        final targetLine = isUpArrow
            ? core.cursorLine - 1
            : core.cursorManager.cursors.last.line + 1;

        if (isAltPressed && isMetaOrCtrlPressed) {
          // TODO add config option to toggle between Zed behavior (use starting cursor as anchor and
          // skip lines where it is impossible for the cursor index to be reached) or VSCode behavior
          // (always extend up or down and include lines that are less than the target cursor index)

          // Multi-cursor behavior
          if (targetLine < 0 ||
              targetLine > core.bufferManager.lines.length - 1) {
            return true;
          }

          core.addCursor(
              targetLine,
              min(core.cursorManager.targetCursorIndex,
                  core.bufferManager.lines[targetLine].length));
        } else {
          _handleSelection(
              core,
              isShiftPressed,
              isUpArrow
                  ? SelectionDirection.previousLine
                  : SelectionDirection.nextLine);
          isUpArrow ? core.moveUp() : core.moveDown();
        }
        return true;
    }
    return false;
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
