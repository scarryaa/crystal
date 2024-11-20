import 'dart:math';

import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/selection_manager.dart';

class SelectionHandler {
  final SelectionManager selectionManager;
  final Buffer buffer;
  final CursorController cursorController;
  final FoldingManager foldingManager;

  SelectionHandler({
    required this.selectionManager,
    required this.buffer,
    required this.cursorController,
    required this.foldingManager,
  });

  TextRange getSelectedLineRange() {
    if (!selectionManager.hasSelection()) {
      // If no selection, return range containing only current line
      int currentLine = cursorController.getCursorLine();
      return TextRange(
        start: Position(line: currentLine, column: 0),
        end: Position(
            line: currentLine, column: buffer.getLineLength(currentLine)),
      );
    }

    // Get all selections and find min/max lines
    var selections = selectionManager.selections;
    int minLine = buffer.lineCount;
    int maxLine = 0;

    for (var selection in selections) {
      minLine = min(minLine, min(selection.startLine, selection.endLine));
      maxLine = max(maxLine, max(selection.startLine, selection.endLine));
    }

    return TextRange(
      start: Position(line: minLine, column: 0),
      end: Position(line: maxLine, column: buffer.getLineLength(maxLine)),
    );
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
    selectionManager.updateSelection(cursorController.cursors);
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
    selectionManager.startSelection(cursorController.cursors);
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
    cursorController.clearAll();

    cursorController.addCursor(endLine, buffer.getLineLength(endLine));
  }

  void _updateCursorForSingleLine(int lineNumber) {
    cursorController.clearAll();
    cursorController.addCursor(lineNumber, buffer.getLineLength(lineNumber));
  }
}
