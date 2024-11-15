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
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final state = getState();
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final bool isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

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
              state.acceptCompletion(state
                  .suggestions[state.selectedSuggestionIndexNotifier.value]);
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
      if (await getState().handleSpecialKeys(
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
            final affectedLines = getState().getSelectedLineRange();
            getState().cut();
            // Update only affected lines
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
            final cursorLine = getState().cursorLine;
            getState().paste();
            // Update from paste position to end of pasted content
            final pastedLines = getState().getLastPastedLineCount();
            for (int line = cursorLine;
                line < cursorLine + pastedLines;
                line++) {
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
            // Control+Home moves to document start
            getState().moveCursorToDocumentStart(isShiftPressed);
          } else {
            // Home moves to line start
            getState().moveCursorToLineStart(isShiftPressed);
          }
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.end:
          if (isControlPressed) {
            // Control+End moves to document end
            getState().moveCursorToDocumentEnd(isShiftPressed);
          } else {
            // End moves to line end
            getState().moveCursorToLineEnd(isShiftPressed);
          }
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.pageUp:
          getState().moveCursorPageUp(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.pageDown:
          getState().moveCursorPageDown(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyP:
          if (isControlPressed) {
            showCommandPalette();
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
            await _handleCloseTab();
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
          getState().moveCursorLeft(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          getState().moveCursorRight(isShiftPressed);
          scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          final currentLine = getState().cursorLine;
          getState().insertNewLine();
          // Update current and next line
          updateSingleLineWidth(currentLine);
          updateSingleLineWidth(currentLine + 1);
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
        case LogicalKeyboardKey.delete:
          final currentLine = getState().cursorLine;
          final hasSelection = getState().hasSelection();

          if (hasSelection) {
            // Get the line range before deleting
            final affectedLines = getState().getSelectedLineRange();

            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              getState().backspace();
            } else {
              getState().delete();
            }

            // Update all affected lines
            for (int line = affectedLines.start;
                line <= affectedLines.end;
                line++) {
              updateSingleLineWidth(line);
            }
          } else {
            if (getState().isLineJoinOperation()) {
              // If operation will join lines, update both lines
              updateSingleLineWidth(currentLine);
              updateSingleLineWidth(currentLine + 1);
            } else {
              // Otherwise just update current line
              updateSingleLineWidth(currentLine);
            }

            if (event.logicalKey == LogicalKeyboardKey.backspace) {
              getState().backspace();
            } else {
              getState().delete();
            }
          }

          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
          final currentLine = getState().cursorLine;
          if (isShiftPressed) {
            getState().backTab();
          } else {
            getState().insertTab();
          }
          updateSingleLineWidth(currentLine);
          scrollToCursor();
          onSearchTermChanged(searchTerm);
          return KeyEventResult.handled;
        default:
          if (event.character != null &&
              event.character!.length == 1 &&
              event.logicalKey != LogicalKeyboardKey.escape) {
            final currentLine = getState().cursorLine;
            getState().insertChar(event.character!);
            updateSingleLineWidth(currentLine);
            scrollToCursor();
            onSearchTermChanged(searchTerm);
            return KeyEventResult.handled;
          }
      }
    }

    return KeyEventResult.ignored;
  }
}
