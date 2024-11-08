import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorKeyboardHandler {
  Function(String searchTerm) onSearchTermChanged;
  Function(int) onEditorClosed;
  Future<void> Function() saveFileAs;
  Future<void> Function() saveFile;
  VoidCallback updateCachedMaxLineWidth;
  VoidCallback scrollToCursor;
  VoidCallback openConfig;
  VoidCallback openDefaultConfig;
  VoidCallback openNewTab;

  final EditorState Function() getState;
  final Function() activeEditorIndex;
  String searchTerm;

  EditorKeyboardHandler({
    required this.onSearchTermChanged,
    required this.onEditorClosed,
    required this.saveFileAs,
    required this.saveFile,
    required this.updateCachedMaxLineWidth,
    required this.scrollToCursor,
    required this.openConfig,
    required this.openDefaultConfig,
    required this.openNewTab,
    required this.getState,
    required this.searchTerm,
    required this.activeEditorIndex,
  });

  KeyEventResult handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final bool isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

      // Special keys
      if (getState().handleSpecialKeys(
          isControlPressed, isShiftPressed, event.logicalKey)) {
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;
      }

      // Ctrl shortcuts
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          if (isControlPressed) {
            getState().copy();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyX:
          if (isControlPressed) {
            getState().cut();
            updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollToCursor();
              onSearchTermChanged(searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyV:
          if (isControlPressed) {
            getState().paste();
            updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollToCursor();
              onSearchTermChanged(searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyA:
          if (isControlPressed) {
            getState().selectAll();
            scrollToCursor();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.comma:
          if (isControlPressed) {
            openConfig();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.less:
          if (isControlPressed) {
            openDefaultConfig();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyW:
          if (isControlPressed) {
            onEditorClosed(activeEditorIndex());
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyN:
          {
            if (isControlPressed) {
              openNewTab();
              return KeyEventResult.handled;
            }
          }
        case LogicalKeyboardKey.keyS:
          {
            if (isControlPressed && isShiftPressed) {
              saveFileAs();
              return KeyEventResult.handled;
            } else if (isControlPressed) {
              saveFile();
              return KeyEventResult.handled;
            }
          }
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          getState().moveCursorDown(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          getState().moveCursorUp(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          getState().moveCursorLeft(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          getState().moveCursorRight(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          getState().insertNewLine();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          getState().backspace();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          getState().delete();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
          if (isShiftPressed) {
            getState().backTab();
          } else {
            getState().insertTab();
            updateCachedMaxLineWidth();
          }
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        default:
          if (event.character != null &&
              event.character!.length == 1 &&
              event.logicalKey != LogicalKeyboardKey.escape) {
            getState().insertChar(event.character!);
            updateCachedMaxLineWidth();
            scrollToCursor();
            onSearchTermChanged(searchTerm);
            return KeyEventResult.handled;
          }
      }
    }

    return KeyEventResult.ignored;
  }
}
