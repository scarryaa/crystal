import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorKeyboardHandler {
  Function(String searchTerm) onSearchTermChanged;
  Function(int) onEditorClosed;
  VoidCallback updateCachedMaxLineWidth;
  VoidCallback scrollToCursor;
  VoidCallback openConfig;
  VoidCallback openDefaultConfig;

  final Function() activeEditorIndex;
  EditorState state;
  String searchTerm;

  EditorKeyboardHandler({
    required this.onSearchTermChanged,
    required this.onEditorClosed,
    required this.updateCachedMaxLineWidth,
    required this.scrollToCursor,
    required this.openConfig,
    required this.openDefaultConfig,
    required this.state,
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
      if (state.handleSpecialKeys(
          isControlPressed, isShiftPressed, event.logicalKey)) {
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;
      }

      // Ctrl shortcuts
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          if (isControlPressed) {
            state.copy();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyX:
          if (isControlPressed) {
            state.cut();
            updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollToCursor();
              onSearchTermChanged(searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyV:
          if (isControlPressed) {
            state.paste();
            updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              scrollToCursor();
              onSearchTermChanged(searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyA:
          if (isControlPressed) {
            state.selectAll();
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
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          state.moveCursorDown(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          state.moveCursorUp(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          state.moveCursorLeft(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          state.moveCursorRight(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          state.insertNewLine();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          state.backspace();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          state.delete();
          updateCachedMaxLineWidth();
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
          if (isShiftPressed) {
            state.backTab();
          } else {
            state.insertTab();
            updateCachedMaxLineWidth();
          }
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        default:
          if (event.character != null &&
              event.character!.length == 1 &&
              event.logicalKey != LogicalKeyboardKey.escape) {
            state.insertChar(event.character!);
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
