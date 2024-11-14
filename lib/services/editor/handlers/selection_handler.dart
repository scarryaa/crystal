import 'dart:math';
import 'dart:ui';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';

class SelectionHandler {
  final EditorSelectionManager selectionManager;
  final Buffer buffer;
  final EditorCursorManager cursorManager;
  final FoldingManager foldingManager;

  SelectionHandler({
    required this.selectionManager,
    required this.buffer,
    required this.cursorManager,
    required this.foldingManager,
  });

  TextRange getSelectedLineRange() {
    if (!selectionManager.hasSelection()) {
      // If no selection, return range containing only current line
      int currentLine = cursorManager.getCursorLine();
      return TextRange(start: currentLine, end: currentLine);
    }

    // Get all selections and find min/max lines
    var selections = selectionManager.selections;
    int minLine = buffer.lineCount;
    int maxLine = 0;

    for (var selection in selections) {
      minLine = min(minLine, min(selection.startLine, selection.endLine));
      maxLine = max(maxLine, max(selection.startLine, selection.endLine));
    }

    return TextRange(start: minLine, end: maxLine);
  }

  void selectAll() {
    selectionManager.selectAll(
        buffer.lineCount - 1, buffer.getLineLength(buffer.lineCount - 1));
  }

  void selectLine(bool extend, int lineNumber) {
    if (!_isValidLineNumber(lineNumber)) return;

    final foldedRegion = foldingManager.getFoldedRegionForLine(lineNumber);
    if (foldedRegion != null) {
      _selectFoldedRegion(extend, foldedRegion);
    } else {
      _selectSingleLine(extend, lineNumber);
    }
  }

  void updateSelection() {
    selectionManager.updateSelection(cursorManager.cursors);
  }

  void clearSelection() {
    selectionManager.clearAll();
  }

  String getSelectedText() {
    return selectionManager.getSelectedText(buffer);
  }

  bool hasSelection() {
    return selectionManager.hasSelection();
  }

  List<Selection> getCurrentSelections() {
    return selectionManager.selections.toList();
  }

  void startSelection() {
    selectionManager.startSelection(cursorManager.cursors);
  }

  bool _isValidLineNumber(int lineNumber) {
    return lineNumber >= 0 && lineNumber < buffer.lineCount;
  }

  void _selectFoldedRegion(bool extend, MapEntry<int, int> foldedRegion) {
    selectionManager.selectLineRange(
      buffer,
      extend,
      foldedRegion.key,
      foldedRegion.value,
    );
    _updateCursorForFoldedRegion(foldedRegion.value);
  }

  void _selectSingleLine(bool extend, int lineNumber) {
    selectionManager.selectLine(buffer, extend, lineNumber);
    _updateCursorForSingleLine(lineNumber);
  }

  void _updateCursorForFoldedRegion(int endLine) {
    cursorManager.clearAll();
    cursorManager.addCursor(Cursor(endLine, buffer.getLineLength(endLine)));
  }

  void _updateCursorForSingleLine(int lineNumber) {
    cursorManager.clearAll();
    cursorManager
        .addCursor(Cursor(lineNumber, buffer.getLineLength(lineNumber)));
  }
}
