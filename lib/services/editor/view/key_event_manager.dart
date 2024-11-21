import 'dart:async';

import 'package:crystal/services/editor/handlers/keyboard/editor_keyboard_handler.dart';
import 'package:flutter/material.dart';

class KeyEventManager {
  final EditorKeyboardHandler editorKeyboardHandler;
  bool isTyping = false;

  KeyEventManager(this.editorKeyboardHandler);

  Future<void> handleKeyEventAsync(FocusNode node, KeyEvent event) async {
    await handleKeyEvent(node, event);
  }

  Future<KeyEventResult> handleKeyEvent(FocusNode node, KeyEvent event) async {
    isTyping = true;
    Timer(const Duration(milliseconds: 500), () {
      isTyping = false;
    });
    return await editorKeyboardHandler.handleKeyEvent(node, event);
  }
}
