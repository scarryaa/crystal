import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutHandler {
  VoidCallback openSettings;
  VoidCallback openDefaultSettings;

  ShortcutHandler({
    required this.openSettings,
    required this.openDefaultSettings,
  });

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      final bool isControlPressed = Platform.isMacOS
          ? HardwareKeyboard.instance.isMetaPressed
          : HardwareKeyboard.instance.isControlPressed;

      if (event.logicalKey == LogicalKeyboardKey.comma) {
        openSettings();
        return KeyEventResult.handled;
        // Note: check for 'less' here instead of shift + ctrl + comma due
        // to the way LogicalKeyboardKey recognizes the key ('left' instead of 'comma')
      } else if (event.logicalKey == LogicalKeyboardKey.less &&
          isControlPressed) {
        openDefaultSettings();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }
}
