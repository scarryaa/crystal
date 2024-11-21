import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/controllers/selection_controller.dart';
import 'package:crystal/services/editor/controllers/text_controller.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:flutter/services.dart';

class CommandHandler {
  final UndoRedoManager undoRedoManager;
  final SelectionController selectionController;
  final CursorController cursorController;
  final TextController textController;
  final Buffer buffer;
  final Function() notifyListeners;
  final Function() getSelectedText;

  CommandHandler({
    required this.undoRedoManager,
    required this.selectionController,
    required this.cursorController,
    required this.textController,
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
    textController.deleteSelection();
    notifyListeners();
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: getSelectedText()));
  }

  Future<void> paste() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    if (selectionController.hasSelection()) {
      textController.deleteSelection();
    }

    String pastedLines = data.text!;
    cursorController.paste(buffer, pastedLines);

    buffer.incrementVersion();
    notifyListeners();
  }
}
