import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorInputManager {
  KeyEventResult handleKeyEvent(EditorCore core, KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    switch (keyEvent.logicalKey) {
      case LogicalKeyboardKey.enter:
        core.insertLine();
        break;
      case LogicalKeyboardKey.backspace:
        core.delete(1);
        break;
      default:
        if (keyEvent.character == null) return KeyEventResult.ignored;

        core.insertChar(keyEvent.character!);
        break;
    }

    return KeyEventResult.handled;
  }

  void handleBackspace(EditorCore core) {
    core.delete(1);
  }
}
