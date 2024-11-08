import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutHandler {
  VoidCallback openSettings;
  VoidCallback openDefaultSettings;
  VoidCallback closeTab;

  ShortcutHandler({
    required this.openSettings,
    required this.openDefaultSettings,
    required this.closeTab,
  });

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

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
      }
    }

    return KeyEventResult.ignored;
  }
}
