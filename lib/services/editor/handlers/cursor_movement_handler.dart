import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';

class CursorMovementHandler {
  final Buffer buffer;
  final FoldingManager foldingManager;
  final EditorCursorManager editorCursorManager;
  final EditorSelectionManager editorSelectionManager;
  final Function() notifyListeners;
  final Function() startSelection;
  final Function() updateSelection;
  final Function() clearSelection;

  CursorMovementHandler({
    required this.buffer,
    required this.foldingManager,
    required this.editorCursorManager,
    required this.editorSelectionManager,
    required this.notifyListeners,
    required this.startSelection,
    required this.updateSelection,
    required this.clearSelection,
  });

  void _moveCursor(
      bool isShiftPressed, void Function(Buffer, FoldingManager) moveFunction) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    moveFunction(buffer, foldingManager);

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveUp);
  }

  void moveCursorDown(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveDown);
  }

  void moveCursorLeft(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveLeft);
  }

  void moveCursorRight(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveRight);
  }
}
