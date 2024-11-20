import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/handlers/selection_handler.dart';

class SelectionOperationsManager {
  final SelectionHandler selectionHandler;
  final EditorSelectionManager selectionManager;
  final EditorCursorManager cursorManager;
  final Buffer buffer;
  final Function() notifyListeners;
  final Function() emitSelectionChangedEvent;

  SelectionOperationsManager({
    required this.selectionHandler,
    required this.cursorManager,
    required this.selectionManager,
    required this.buffer,
    required this.notifyListeners,
    required this.emitSelectionChangedEvent,
  });

  void selectAll() {
    selectionHandler.selectAll();
    emitSelectionChangedEvent();
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    selectionHandler.selectLine(extend, lineNumber);
    emitSelectionChangedEvent();
    notifyListeners();
  }

  void startSelection() {
    selectionHandler.startSelection();
    emitSelectionChangedEvent();
    notifyListeners();
  }

  bool hasSelection() {
    return selectionHandler.hasSelection();
  }

  TextRange getSelectedLineRange() {
    return selectionHandler.getSelectedLineRange();
  }

  String getSelectedText() {
    return selectionManager.getSelectedText(buffer);
  }

  void restoreSelections(List<Selection> selections) {
    selectionManager.clearAll();
    for (var selection in selections) {
      selectionManager.addSelection(selection);
    }
    emitSelectionChangedEvent();
    notifyListeners();
  }

  void clearSelection() {
    selectionManager.clearAll();
    notifyListeners();
    emitSelectionChangedEvent();
  }

  void updateSelection() {
    selectionManager.updateSelection(cursorManager.cursors);
    emitSelectionChangedEvent();

    notifyListeners();
  }
}
