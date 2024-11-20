import 'package:crystal/models/editor/commands/editing_commands.dart';
import 'package:crystal/services/editor/handlers/keyboard/keyboard_handler_base.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TextEditingHandler extends KeyboardHandlerBase {
  final EditingCommands editingCommands;
  final Function(int) updateSingleLineWidth;
  final Function(String) onSearchTermChanged;
  final String searchTerm;

  TextEditingHandler({
    required EditorState Function() getState,
    required VoidCallback scrollToCursor,
    required this.editingCommands,
    required this.updateSingleLineWidth,
    required this.onSearchTermChanged,
    required this.searchTerm,
  }) : super(
          getState,
          scrollToCursor,
        );

  Future<KeyEventResult> handleCopyPaste(
      LogicalKeyboardKey key, bool isControlPressed) async {
    if (!isControlPressed) return KeyEventResult.ignored;

    switch (key) {
      case LogicalKeyboardKey.keyC:
        editingCommands.copy();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyX:
        final affectedLines = editingCommands.getSelectedLineRange();
        editingCommands.cut();
        for (int line = affectedLines.start.line;
            line <= affectedLines.end.line;
            line++) {
          updateSingleLineWidth(line);
        }
        scrollToCursor();
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyV:
        final state = getState();
        final cursorLine = state.cursorLine;
        editingCommands.paste();
        final pastedLines = editingCommands.getLastPastedLineCount();
        for (int line = cursorLine; line < cursorLine + pastedLines; line++) {
          updateSingleLineWidth(line);
        }
        scrollToCursor();
        onSearchTermChanged(searchTerm);
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  KeyEventResult handleNewLine() {
    final currentLine = getState().cursorLine;
    editingCommands.insertNewLine();
    updateSingleLineWidth(currentLine);
    updateSingleLineWidth(currentLine + 1);
    scrollToCursor();
    onSearchTermChanged(searchTerm);
    return KeyEventResult.handled;
  }

  KeyEventResult handleDelete(LogicalKeyboardKey key) {
    final state = getState();
    final currentLine = state.cursorLine;
    final hasSelection = state.hasSelection();

    if (hasSelection) {
      final affectedLines = editingCommands.getSelectedLineRange();
      if (key == LogicalKeyboardKey.backspace) {
        editingCommands.backspace();
      } else {
        editingCommands.delete();
      }
      for (int line = affectedLines.start.line;
          line <= affectedLines.end.line;
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
      if (key == LogicalKeyboardKey.backspace) {
        editingCommands.backspace();
      } else {
        editingCommands.delete();
      }
    }
    scrollToCursor();
    onSearchTermChanged(searchTerm);
    return KeyEventResult.handled;
  }

  KeyEventResult handleTab(bool isShiftPressed) {
    final currentLine = getState().cursorLine;
    if (isShiftPressed) {
      editingCommands.backTab();
    } else {
      editingCommands.insertTab();
    }
    updateSingleLineWidth(currentLine);
    scrollToCursor();
    onSearchTermChanged(searchTerm);
    return KeyEventResult.handled;
  }

  KeyEventResult handleCharacterInsertion(KeyEvent event) {
    if (!_isValidCharacter(event)) return KeyEventResult.ignored;

    final state = getState();
    final currentLine = state.cursorLine;
    editingCommands.insertChar(event.character!);
    updateSingleLineWidth(currentLine);
    scrollToCursor();
    onSearchTermChanged(searchTerm);
    return KeyEventResult.handled;
  }

  bool _isValidCharacter(KeyEvent event) {
    if (event.character == null) return false;
    if (HardwareKeyboard.instance.isControlPressed) return false;

    final charCode = event.character!.codeUnitAt(0);
    return charCode >= 32 && charCode < 127 || charCode > 127;
  }
}
