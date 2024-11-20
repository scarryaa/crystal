import 'package:crystal/models/editor/commands/file_commands.dart';
import 'package:crystal/services/dialog_service.dart';
import 'package:crystal/services/editor/handlers/keyboard/keyboard_handler_base.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FileHandler extends KeyboardHandlerBase {
  final FileCommands fileCommands;
  final bool isDirty;
  final Function(int) onEditorClosed;
  final Function() activeEditorIndex;

  FileHandler({
    required EditorState Function() getState,
    required VoidCallback scrollToCursor,
    required this.fileCommands,
    required this.isDirty,
    required this.onEditorClosed,
    required this.activeEditorIndex,
  }) : super(
          getState,
          scrollToCursor,
        );

  Future<KeyEventResult> handleFileOperation(LogicalKeyboardKey key,
      bool isControlPressed, bool isShiftPressed) async {
    if (!isControlPressed) return KeyEventResult.ignored;

    switch (key) {
      case LogicalKeyboardKey.keyS:
        if (isShiftPressed) {
          await fileCommands.saveFileAs();
        } else {
          await fileCommands.saveFile();
        }
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyN:
        fileCommands.openNewTab();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.keyW:
        await _handleCloseTab();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.comma:
        fileCommands.openConfig();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.less:
        fileCommands.openDefaultConfig();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }

  Future<void> _handleCloseTab() async {
    if (isDirty) {
      final response = await DialogService().showSavePrompt();
      switch (response) {
        case 'Save & Exit':
          await fileCommands.saveFile();
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
}
