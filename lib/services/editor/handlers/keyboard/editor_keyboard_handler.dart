import 'dart:io';

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/services/editor/handlers/keyboard/file_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/navigation_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/text_editing_handler.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorKeyboardHandler {
  final FileHandler fileHandler;
  final TextEditingHandler textEditingHandler;
  final NavigationHandler navigationHandler;
  final EditorState Function() getState;
  final void Function([CommandPaletteMode mode]) showCommandPalette;
  final Function(String) onSearchTermChanged;
  final String searchTerm;

  EditorKeyboardHandler({
    required this.fileHandler,
    required this.textEditingHandler,
    required this.navigationHandler,
    required this.getState,
    required this.showCommandPalette,
    required this.onSearchTermChanged,
    required this.searchTerm,
  });

  Future<KeyEventResult> handleKeyEvent(FocusNode node, KeyEvent event) async {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final state = getState();
    final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
    final bool isMac = Platform.isMacOS;
    final bool isControlPressed = isMac
        ? HardwareKeyboard.instance.isMetaPressed
        : HardwareKeyboard.instance.isControlPressed;

    // Handle completions
    if (state.showCompletions) {
      final result = _handleCompletions(event, state);
      if (result != KeyEventResult.ignored) return result;
    }

    // Handle special keys
    if (await state.handleSpecialKeys(
        isControlPressed, isShiftPressed, event.logicalKey)) {
      onSearchTermChanged(searchTerm);
      return KeyEventResult.handled;
    }

    // Handle command palette
    if (isControlPressed && event.logicalKey == LogicalKeyboardKey.keyP) {
      showCommandPalette(isShiftPressed
          ? CommandPaletteMode.commands
          : CommandPaletteMode.files);
      return KeyEventResult.handled;
    }

    // Delegate to specific handlers
    return await _delegateKeyEvent(
      event,
      isControlPressed,
      isShiftPressed,
    );
  }

  KeyEventResult _handleCompletions(KeyEvent event, EditorState state) {
    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        state.selectNextSuggestion();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        state.selectPreviousSuggestion();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        if (state.suggestions.isNotEmpty) {
          state.selectNextSuggestion();
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.enter:
        if (state.suggestions.isNotEmpty) {
          state.acceptCompletion(
              state.suggestions[state.selectedSuggestionIndexNotifier.value]);
          return KeyEventResult.handled;
        }
        break;
      case LogicalKeyboardKey.escape:
        state.showCompletions = false;
        state.resetSuggestionSelection();
        return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<KeyEventResult> _delegateKeyEvent(
    KeyEvent event,
    bool isControlPressed,
    bool isShiftPressed,
  ) async {
    // File operations
    final fileResult = await fileHandler.handleFileOperation(
      event.logicalKey,
      isControlPressed,
      isShiftPressed,
    );
    if (fileResult != KeyEventResult.ignored) return fileResult;

    // Text editing operations
    if (isControlPressed) {
      final editResult = await textEditingHandler.handleCopyPaste(
        event.logicalKey,
        isControlPressed,
      );
      if (editResult != KeyEventResult.ignored) return editResult;
    }

    // Handle special editing keys
    switch (event.logicalKey) {
      case LogicalKeyboardKey.enter:
        return textEditingHandler.handleNewLine();

      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        return textEditingHandler.handleDelete(event.logicalKey);

      case LogicalKeyboardKey.tab:
        return textEditingHandler.handleTab(isShiftPressed);
    }

    // Navigation operations
    final navResult = navigationHandler.handleNavigation(
      event.logicalKey,
      isShiftPressed,
      isControlPressed,
    );
    if (navResult != KeyEventResult.ignored) return navResult;

    // Character insertion (only if no control key is pressed)
    if (!isControlPressed) {
      return textEditingHandler.handleCharacterInsertion(event);
    }

    return KeyEventResult.ignored;
  }
}
