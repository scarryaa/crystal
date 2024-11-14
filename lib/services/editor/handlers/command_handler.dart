import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:flutter/services.dart';

class CommandHandler {
  final UndoRedoManager undoRedoManager;
  final EditorSelectionManager editorSelectionManager;
  final EditorCursorManager editorCursorManager;
  final TextManipulator textManipulator;
  final Buffer buffer;
  final Function() notifyListeners;
  final Function() getSelectedText;

  CommandHandler({
    required this.undoRedoManager,
    required this.editorSelectionManager,
    required this.editorCursorManager,
    required this.textManipulator,
    required this.buffer,
    required this.notifyListeners,
    required this.getSelectedText,
  });

  bool get canUndo => undoRedoManager.canUndo;
  bool get canRedo => undoRedoManager.canRedo;

  void undo() {
    undoRedoManager.undo();
    notifyListeners();
  }

  void redo() {
    undoRedoManager.redo();
    notifyListeners();
  }

  void cut() {
    copy();
    textManipulator.deleteSelection();
    notifyListeners();
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: getSelectedText()));
  }

  Future<void> paste() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    if (editorSelectionManager.hasSelection()) {
      textManipulator.deleteSelection();
    }

    String pastedLines = data.text!;
    editorCursorManager.paste(buffer, pastedLines);

    buffer.incrementVersion();
    notifyListeners();
  }
}
