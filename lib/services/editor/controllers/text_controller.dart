import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/controllers/selection_controller.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';

class TextController {
  final Buffer buffer;
  final CursorController cursorController;
  final SelectionController selectionController;
  final FoldingManager foldingManager;
  final UndoRedoManager undoRedoManager;
  final Function() onTextChanged;
  final Function() updateCompletions;
  final Function() notifyListeners;

  TextController({
    required this.buffer,
    required this.selectionController,
    required this.cursorController,
    required this.foldingManager,
    required this.undoRedoManager,
    required this.onTextChanged,
    required this.updateCompletions,
    required this.notifyListeners,
  });

  // Public methods for text operations
  void insertNewLine() {
    if (selectionController.hasSelection()) {
      deleteSelection();
    }
    cursorController.insertNewLine(buffer);
    _notifyChanges();
  }

  void backspace() {
    if (selectionController.hasSelection()) {
      deleteSelection();
      return;
    }
    _unfoldBeforeBackspace();
    _performBackspace();
    _updateFoldedRegions();
    _notifyChanges();
  }

  void delete() {
    if (selectionController.hasSelection()) {
      deleteSelection();
      return;
    }
    _unfoldBeforeDelete();
    _performDelete();
    _updateFoldedRegions();
    _notifyChanges();
  }

  void insertChar(String c) {
    if (selectionController.hasSelection()) {
      deleteSelection();
    }

    final affectedLines = <int>{};
    var sortedCursors = _getSortedCursors();

    for (int i = 0; i < sortedCursors.length; i++) {
      var currentCursor = sortedCursors[i];
      affectedLines.add(currentCursor.line);

      String currentLine = buffer.getLine(currentCursor.line);
      String newLine;

      if (cursorController.insertMode) {
        newLine = currentLine.substring(0, currentCursor.column) +
            c +
            currentLine.substring(currentCursor.column);
      } else {
        if (currentCursor.column >= currentLine.length) {
          newLine = currentLine + c;
        } else {
          newLine = currentLine.substring(0, currentCursor.column) +
              c +
              currentLine.substring(currentCursor.column + 1);
        }
      }

      buffer.setLine(currentCursor.line, newLine);
      _adjustLaterCursors(sortedCursors, i, c.length);
      currentCursor.column++;
    }

    _updateFoldedRegionsAfterEdit(affectedLines);
    _notifyChanges();
  }

  void deleteSelection() {
    if (!selectionController.hasSelection()) return;

    // Sort selections in reverse order to handle overlapping selections correctly
    var sortedSelections = List<Selection>.from(selectionController.selections)
      ..sort((a, b) => b.startLine.compareTo(a.startLine));

    // Track folded regions that need to be removed
    final foldedRegionsToRemove = <int>{};

    // Check all folded regions that intersect with selections
    for (var selection in sortedSelections) {
      final startLine = min(selection.startLine, selection.endLine);
      final endLine = max(selection.startLine, selection.endLine);

      // Check each folded region
      for (final entry in buffer.foldedRanges.entries) {
        final foldStart = entry.key;
        final foldEnd = entry.value;

        // Check if selection contains closing bracket of fold
        if (foldingManager.selectionContainsFoldEnd(selection, foldEnd)) {
          foldedRegionsToRemove.add(foldStart);
          continue;
        }

        // Cases where we need to remove the folded region:
        // 1. Selection completely contains the folded region
        // 2. Selection starts within the folded region
        // 3. Selection ends within the folded region
        // 4. Folded region completely contains the selection
        if ((startLine <= foldStart && endLine >= foldEnd) || // Case 1
            (startLine >= foldStart && startLine <= foldEnd) || // Case 2
            (endLine >= foldStart && endLine <= foldEnd) || // Case 3
            (foldStart <= startLine && foldEnd >= endLine)) {
          // Case 4
          foldedRegionsToRemove.add(foldStart);
        }
      }
    }

    // Remove affected folded regions before deleting text
    for (final foldStart in foldedRegionsToRemove) {
      buffer.unfoldLines(foldStart);
      foldingManager.toggleFold(
          foldStart, buffer.foldedRanges[foldStart] ?? foldStart);
    }

    // Perform deletion
    var newStartLinesColumns = selectionController.deleteSelection(buffer);
    cursorController.setAllCursors(newStartLinesColumns);
    buffer.incrementVersion();

    // Clean up any remaining folded regions that might be invalid
    final remainingFolds = Map<int, int>.from(buffer.foldedRanges);
    for (final entry in remainingFolds.entries) {
      if (entry.key >= buffer.lineCount || entry.value >= buffer.lineCount) {
        buffer.unfoldLines(entry.key);
        foldingManager.toggleFold(entry.key, entry.value);
      }
    }

    notifyListeners();
  }

  void insertTab() {
    if (selectionController.hasSelection()) {
      var newCursors =
          selectionController.insertTab(buffer, cursorController.cursors);
      cursorController.setAllCursors(newCursors);
    } else {
      insertChar('    ');
    }
    _notifyChanges();
  }

  void backTab() {
    if (selectionController.hasSelection()) {
      var newCursors =
          selectionController.backTab(buffer, cursorController.cursors);
      cursorController.setAllCursors(newCursors);
    } else {
      cursorController.backTab(buffer);
    }
    _notifyChanges();
  }

  void executeCommand(Command command) {
    undoRedoManager.executeCommand(command);
    _notifyChanges();
  }

  List<Cursor> _getSortedCursors() {
    return List.from(cursorController.cursors)
      ..sort((a, b) {
        if (a.line != b.line) return a.line.compareTo(b.line);
        return a.column.compareTo(b.column);
      });
  }

  void _adjustLaterCursors(
      List<Cursor> sortedCursors, int currentIndex, int adjustment) {
    if (currentIndex < sortedCursors.length - 1) {
      for (int j = currentIndex + 1; j < sortedCursors.length; j++) {
        var laterCursor = sortedCursors[j];
        var currentCursor = sortedCursors[currentIndex];
        if (laterCursor.line == currentCursor.line &&
            laterCursor.column > currentCursor.column) {
          laterCursor.column += adjustment;
        }
      }
    }
  }

  void _unfoldBeforeDelete() {
    for (var cursor in cursorController.cursors) {
      _unfoldAtCursorForDelete(cursor);
      _unfoldAtClosingSymbolForDelete(cursor);
    }
  }

  void _unfoldAtCursorForDelete(Cursor cursor) {
    final lineContent = buffer.getLine(cursor.line);
    if (cursor.column < lineContent.length) {
      final charAtCursor = lineContent[cursor.column];

      if ('{([<'.contains(charAtCursor) &&
          foldingManager.isFolded(cursor.line)) {
        foldingManager.unfold(cursor.line);
      }
    }
  }

  void _unfoldAtClosingSymbolForDelete(Cursor cursor) {
    for (var entry in foldingManager.foldedRegions.entries) {
      final foldStart = entry.key;
      final foldEnd = entry.value;
      final lineContent = buffer.getLine(foldEnd);

      if (foldingManager.isCursorAtClosingSymbol(
          cursor, lineContent, foldEnd, false)) {
        foldingManager.unfold(foldStart);
        break;
      }
    }
  }

  void _updateFoldedRegions() {
    final affectedLines =
        cursorController.cursors.map((cursor) => cursor.line).toSet();
    foldingManager.updateFoldedRegionsAfterEdit(affectedLines);
  }

  void _unfoldBeforeBackspace() {
    for (var cursor in cursorController.cursors) {
      foldingManager.unfoldAtCursor(cursor);
      foldingManager.unfoldBeforeCursor(cursor);
      foldingManager.unfoldAtClosingSymbol(cursor);
    }
  }

  void _updateFoldedRegionsAfterEdit(Set<int> affectedLines) {
    // Get all folded regions that contain affected lines
    final regionsToCheck = <int, int>{};

    // Also check the line itself for any fold starts
    for (final line in affectedLines) {
      if (buffer.foldedRanges.containsKey(line)) {
        regionsToCheck[line] = buffer.foldedRanges[line]!;
      }
    }

    // Check each affected folded region
    for (final entry in regionsToCheck.entries) {
      final startLine = entry.key;
      final originalEndLine = entry.value;

      // Check if the folded region is still valid
      final newEndLine =
          foldingManager.getFoldableRegionEnd(startLine, buffer.lines);
      if (newEndLine == null || newEndLine != originalEndLine) {
        // Region is no longer valid, unfold it
        buffer.unfoldLines(startLine);
        foldingManager.toggleFold(startLine, originalEndLine);
      }
    }
  }

  void _performDelete() {
    cursorController.delete(buffer);
    buffer.incrementVersion();
  }

  void _performBackspace() {
    cursorController.backspace(buffer);
    buffer.incrementVersion();
  }

  // Helper method to handle notifications
  void _notifyChanges() {
    buffer.incrementVersion();
    updateCompletions();
    onTextChanged();
    notifyListeners();
  }
}
