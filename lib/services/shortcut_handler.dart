import 'dart:io';

import 'package:crystal/services/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShortcutHandler {
  VoidCallback openSettings;
  VoidCallback openDefaultSettings;
  VoidCallback closeTab;
  VoidCallback openNewTab;
  VoidCallback requestEditorFocus;
  Future<void> Function() saveFileAs;
  Future<void> Function() saveFile;
  bool Function() isDirty;
  VoidCallback showCommandPalette;

  ShortcutHandler({
    required this.openSettings,
    required this.openDefaultSettings,
    required this.closeTab,
    required this.openNewTab,
    required this.requestEditorFocus,
    required this.saveFileAs,
    required this.saveFile,
    required this.isDirty,
    required this.showCommandPalette,
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
        case LogicalKeyboardKey.less:
          if (isControlPressed) {
            openDefaultSettings();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyW:
          if (isControlPressed) {
            _handleCloseTab();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyN:
          if (isControlPressed) {
            openNewTab();
            requestEditorFocus();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyS:
          if (isControlPressed && isShiftPressed) {
            saveFileAs();
            return KeyEventResult.handled;
          } else if (isControlPressed) {
            saveFile();
            return KeyEventResult.handled;
          }
          break;
        case LogicalKeyboardKey.keyP:
          if (isControlPressed && !isShiftPressed) {
            showCommandPalette();
            return KeyEventResult.handled;
          }
          break;
      }
    }
    return KeyEventResult.ignored;
  }

  void _handleCloseTab() async {
    if (isDirty()) {
      final response = await DialogService().showSavePrompt();
      switch (response) {
        case 'Save & Exit':
          await saveFile();
          closeTab();
          break;
        case 'Exit without Saving':
          closeTab();
          break;
        case 'Cancel':
        default:
          // Do nothing, continue editing
          break;
      }
    } else {
      closeTab();
    }
  }
}
