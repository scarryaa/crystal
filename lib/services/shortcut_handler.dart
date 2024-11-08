import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutHandler {
  VoidCallback openSettings;
  VoidCallback openDefaultSettings;
  VoidCallback closeTab;
  VoidCallback openNewTab;
  Future<void> Function() saveFileAs;
  Future<void> Function() saveFile;

  ShortcutHandler({
    required this.openSettings,
    required this.openDefaultSettings,
    required this.closeTab,
    required this.openNewTab,
    required this.saveFileAs,
    required this.saveFile,
  });

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final bool isControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

      switch (event.logicalKey) {
        case LogicalKeyboardKey.comma:
          openSettings();
          return KeyEventResult.handled;

        // Note: check for 'less' here instead of shift + ctrl + comma due
        // to the way LogicalKeyboardKey recognizes the key ('left' instead of 'comma')
        case LogicalKeyboardKey.less:
          if (isControlPressed) {
            openDefaultSettings();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyW:
          if (isControlPressed) {
            closeTab();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyN:
          if (isControlPressed) {
            openNewTab();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyS:
          if (isControlPressed && isShiftPressed) {
            saveFileAs();
            return KeyEventResult.handled;
          } else if (isControlPressed) {
            saveFile();
            return KeyEventResult.handled;
          }
      }
    }

    return KeyEventResult.ignored;
  }
}
