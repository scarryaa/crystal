import 'dart:io';
import 'package:crystal/services/dialog_service.dart';
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
  Function(int lineIndex) updateSingleLineWidth;
  bool Function() isDirty;
  VoidCallback showCommandPalette;
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
    required this.updateSingleLineWidth,
    required this.isDirty,
    required this.showCommandPalette,
  });

  Future<void> _handleCloseTab() async {
    if (isDirty()) {
      final response = await DialogService().showSavePrompt();
      switch (response) {
        case 'Save & Exit':
          await saveFile();
          onEditorClosed(activeEditorIndex());
          break;
        case 'Exit without Saving':
          onEditorClosed(activeEditorIndex());
          break;
        case 'Cancel':
        default:
          // Do nothing, continue editing
          break;
      }
    } else {
      onEditorClosed(activeEditorIndex());
    }
  }

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

    if (state.showCompletions) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          state.selectNextSuggestion();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          state.selectPreviousSuggestion();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
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
    }

    // Special keys
    if (await state.handleSpecialKeys(
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
          final affectedLines = state.getSelectedLineRange();
          state.cut();
          for (int line = affectedLines.start;
              line <= affectedLines.end;
              line++) {
            updateSingleLineWidth(line);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToCursor();
            onSearchTermChanged(searchTerm);
          });
          return KeyEventResult.handled;
        }
      case LogicalKeyboardKey.keyV:
        if (isControlPressed) {
          final cursorLine = state.cursorLine;
          state.paste();
          final pastedLines = state.getLastPastedLineCount();
          for (int line = cursorLine; line < cursorLine + pastedLines; line++) {
            updateSingleLineWidth(line);
          }
          WidgetsBinding.instance.addPostFrameCallback((_) {
            scrollToCursor();
            onSearchTermChanged(searchTerm);
          });
          return KeyEventResult.handled;
        }
      case LogicalKeyboardKey.home:
        if (isControlPressed) {
          state.moveCursorToDocumentStart(isShiftPressed);
        } else {
          state.moveCursorToLineStart(isShiftPressed);
        }
        scrollToCursor();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.end:
        if (isControlPressed) {
          state.moveCursorToDocumentEnd(isShiftPressed);
        } else {
          state.moveCursorToLineEnd(isShiftPressed);
        }
        scrollToCursor();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageUp:
        state.moveCursorPageUp(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.pageDown:
        state.moveCursorPageDown(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyP:
        if (isControlPressed) {
          showCommandPalette();
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
          await _handleCloseTab();
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

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowDown:
        if (!state.showCompletions) {
          state.moveCursorDown(isShiftPressed);
          scrollToCursor();
        }
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowUp:
        if (!state.showCompletions) {
          state.moveCursorUp(isShiftPressed);
          scrollToCursor();
        }
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
        final currentLine = state.cursorLine;
        state.insertNewLine();
        updateSingleLineWidth(currentLine);
        updateSingleLineWidth(currentLine + 1);
        scrollToCursor();
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.backspace:
      case LogicalKeyboardKey.delete:
        final currentLine = state.cursorLine;
        final hasSelection = state.hasSelection();
        if (hasSelection) {
          final affectedLines = state.getSelectedLineRange();
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            state.backspace();
          } else {
            state.delete();
          }
          for (int line = affectedLines.start;
              line <= affectedLines.end;
              line++) {
            updateSingleLineWidth(line);
          }
        } else {
          if (state.isLineJoinOperation()) {
            updateSingleLineWidth(currentLine);
            updateSingleLineWidth(currentLine + 1);
          } else {
            updateSingleLineWidth(currentLine);
          }
          if (event.logicalKey == LogicalKeyboardKey.backspace) {
            state.backspace();
          } else {
            state.delete();
          }
        }
        scrollToCursor();
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.tab:
        final currentLine = state.cursorLine;
        if (isShiftPressed) {
          state.backTab();
        } else {
          state.insertTab();
        }
        updateSingleLineWidth(currentLine);
        scrollToCursor();
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;
      default:
        if (event.character != null &&
            event.character!.length == 1 &&
            event.logicalKey != LogicalKeyboardKey.escape) {
          final currentLine = state.cursorLine;
          state.insertChar(event.character!);
          updateSingleLineWidth(currentLine);
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        }
    }

    return KeyEventResult.ignored;
  }
}
