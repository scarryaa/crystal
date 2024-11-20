import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/handlers/cursor_movement_handler.dart';

class CursorOperationsManager {
  final EditorCursorManager cursorManager;
  final CursorMovementHandler movementHandler;
  final Function() emitCursorChangedEvent;
  final Function() notifyListeners;

  CursorOperationsManager({
    required this.cursorManager,
    required this.movementHandler,
    required this.emitCursorChangedEvent,
    required this.notifyListeners,
  });

  void moveCursorToLineStart(bool isShiftPressed) {
    movementHandler.moveCursorToLineStart(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorToLineEnd(bool isShiftPressed) {
    movementHandler.moveCursorToLineEnd(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorToDocumentStart(bool isShiftPressed) {
    movementHandler.moveCursorToDocumentStart(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorToDocumentEnd(bool isShiftPressed) {
    movementHandler.moveCursorToDocumentEnd(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorPageUp(bool isShiftPressed) {
    movementHandler.moveCursorPageUp(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorPageDown(bool isShiftPressed) {
    movementHandler.moveCursorPageDown(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorUp(bool isShiftPressed) {
    movementHandler.moveCursorUp(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorDown(bool isShiftPressed) {
    movementHandler.moveCursorDown(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorLeft(bool isShiftPressed) {
    movementHandler.moveCursorLeft(isShiftPressed);
    emitCursorChangedEvent();
  }

  void moveCursorRight(bool isShiftPressed) {
    movementHandler.moveCursorRight(isShiftPressed);
    emitCursorChangedEvent();
  }

  void toggleCaret() {
    cursorManager.toggleCaret();
    notifyListeners();
  }

  bool get showCaret => cursorManager.showCaret;
  set showCaret(bool show) => cursorManager.showCaret = show;

  CursorShape get cursorShape => cursorManager.cursorShape;
  int get cursorLine => cursorManager.getCursorLine();
}
