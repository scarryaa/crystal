import 'dart:math' as math;
import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/folding_manager.dart';

class SelectionController {
  List<Selection> _selections = [];
  final CursorController cursorController;
  final Buffer buffer;
  FoldingManager? foldingManager;
  final Function() notifyListeners;
  Function()? emitSelectionChangedEvent;

  List<Selection> get selections => _selections;

  SelectionController({
    required this.cursorController,
    required this.buffer,
    required this.foldingManager,
    required this.notifyListeners,
    required this.emitSelectionChangedEvent,
  });

  bool hasSelection() => _selections.isNotEmpty;

  List<Selection> getCurrentSelections() {
    return selections.toList();
  }

  void updateSelection() {
    if (emitSelectionChangedEvent == null) return;

    _updateSelectionWithCursors(cursorController.cursors);
    emitSelectionChangedEvent!();
    notifyListeners();
  }

  void _updateSelectionWithCursors(List<Cursor> cursors) {
    if (foldingManager == null) return;

    for (int i = 0; i < math.min(cursors.length, _selections.length); i++) {
      var cursor = cursors[i];
      // Check for folded region at cursor position
      var foldedRegion = foldingManager!.getFoldedRegionForLine(cursor.line);
      if (foldedRegion != null) {
        cursor = Cursor(
            foldedRegion.value, buffer.getLineLength(foldedRegion.value));
      }
      _selections[i] = _updateSingleSelection(_selections[i], cursor);
    }
  }

  String getSelectedText() {
    if (foldingManager == null) return '';

    StringBuffer sb = StringBuffer();
    for (var selection in _selections) {
      if (selection.startLine == selection.endLine) {
        String line = buffer.getLine(selection.startLine);
        sb.write(line.substring(selection.startColumn, selection.endColumn));
        continue;
      }

      // Handle first line
      sb.write(
          buffer.getLine(selection.startLine).substring(selection.startColumn));
      sb.write('\n');

      // Handle middle lines with folding awareness
      for (int i = selection.startLine + 1; i < selection.endLine; i++) {
        var foldedRegion = foldingManager!.getFoldedRegionForLine(i);
        if (foldedRegion != null) {
          i = foldedRegion.value; // Skip to end of folded region
          continue;
        }
        sb.write(buffer.getLine(i));
        sb.write('\n');
      }

      // Handle last line
      sb.write(
          buffer.getLine(selection.endLine).substring(0, selection.endColumn));
    }
    return sb.toString();
  }

  Selection _updateSingleSelection(
      Selection currentSelection, Cursor currentCursor) {
    return _isSelectingBackwards(currentSelection, currentCursor)
        ? _createBackwardsSelection(currentSelection, currentCursor)
        : _createForwardsSelection(currentSelection, currentCursor);
  }

  bool _isSelectingBackwards(Selection selection, Cursor cursor) {
    return cursor.line < selection.anchorLine ||
        (cursor.line == selection.anchorLine &&
            cursor.column < selection.anchorColumn);
  }

  Selection _createBackwardsSelection(Selection selection, Cursor cursor) {
    return Selection(
      startLine: cursor.line,
      endLine: selection.anchorLine,
      startColumn: cursor.column,
      endColumn: selection.anchorColumn,
      anchorLine: selection.anchorLine,
      anchorColumn: selection.anchorColumn,
    );
  }

  Selection _createForwardsSelection(Selection selection, Cursor cursor) {
    return Selection(
      startLine: selection.anchorLine,
      endLine: cursor.line,
      startColumn: selection.anchorColumn,
      endColumn: cursor.column,
      anchorLine: selection.anchorLine,
      anchorColumn: selection.anchorColumn,
    );
  }

  void selectAll() {
    if (emitSelectionChangedEvent == null) return;

    final lastLine = buffer.lineCount - 1;
    _selections.clear();
    _selections.add(Selection(
        startLine: 0,
        endLine: lastLine,
        startColumn: 0,
        endColumn: buffer.getLineLength(lastLine),
        anchorLine: lastLine,
        anchorColumn: buffer.getLineLength(lastLine)));
    emitSelectionChangedEvent!();
    notifyListeners();
  }

  TextRange getSelectedLineRange() {
    if (!hasSelection()) {
      int currentLine = cursorController.getCursorLine();
      return TextRange(
          start: Position(line: currentLine, column: 0),
          end: Position(
              line: currentLine, column: buffer.getLineLength(currentLine)));
    }

    int minLine = buffer.lineCount;
    int maxLine = 0;

    for (var selection in _selections) {
      minLine =
          math.min(minLine, math.min(selection.startLine, selection.endLine));
      maxLine =
          math.max(maxLine, math.max(selection.startLine, selection.endLine));
    }

    return TextRange(
        start: Position(line: minLine, column: 0),
        end: Position(line: maxLine, column: buffer.getLineLength(maxLine)));
  }

  void setAllSelections(List<Selection> selections) {
    _selections = selections;
  }

  void startIndividualSelection(Cursor cursor) {
    _selections.add(Selection(
        startLine: cursor.line,
        endLine: cursor.line,
        startColumn: cursor.column,
        endColumn: cursor.column,
        anchorLine: cursor.line,
        anchorColumn: cursor.column));
  }

  void startSelection(List<Cursor> cursors) {
    _selections.clear();
    for (var cursor in cursors) {
      _selections.add(Selection(
        startLine: cursor.line,
        endLine: cursor.line,
        startColumn: cursor.column,
        endColumn: cursor.column,
        anchorLine: cursor.line,
        anchorColumn: cursor.column,
      ));
    }
  }

  void updateSelectionToLine(Buffer buffer, int line, int column) {
    if (_selections.isEmpty) return;

    var currentSelection = _selections[0];
    if (line < currentSelection.anchorLine ||
        (line == currentSelection.anchorLine &&
            column < currentSelection.anchorColumn)) {
      // Selecting backwards
      _selections[0] = Selection(
        startLine: line,
        endLine: currentSelection.anchorLine,
        startColumn: column,
        endColumn: currentSelection.anchorColumn,
        anchorLine: currentSelection.anchorLine,
        anchorColumn: currentSelection.anchorColumn,
      );
    } else {
      // Selecting forwards
      _selections[0] = Selection(
        startLine: currentSelection.anchorLine,
        endLine: line,
        startColumn: currentSelection.anchorColumn,
        endColumn: column,
        anchorLine: currentSelection.anchorLine,
        anchorColumn: currentSelection.anchorColumn,
      );
    }
  }

  void selectLineRange(Buffer buffer, bool extend, int startLine, int endLine) {
    if (extend && _selections.isNotEmpty) {
      // Extend existing selection
      Selection currentSelection = _selections.first;
      if (startLine < currentSelection.anchorLine) {
        _selections[0] = Selection(
          startLine: startLine,
          endLine: currentSelection.anchorLine,
          startColumn: 0,
          endColumn: buffer.getLineLength(currentSelection.anchorLine),
          anchorLine: currentSelection.anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
      } else {
        _selections[0] = Selection(
          startLine: currentSelection.anchorLine,
          endLine: endLine,
          startColumn: 0,
          endColumn: buffer.getLineLength(endLine),
          anchorLine: currentSelection.anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
      }
    } else {
      // Create new selection
      clearAll();
      _selections.add(Selection(
        startLine: startLine,
        endLine: endLine,
        startColumn: 0,
        endColumn: buffer.getLineLength(endLine),
        anchorLine: startLine,
        anchorColumn: 0,
      ));
    }
  }

  void clearAll() {
    _selections.clear();
  }

  List<Cursor> deleteSelection(Buffer buffer) {
    List<Cursor> newCursors = [];

    // Sort selections in reverse order to handle multiple deletions correctly
    var sortedSelections = List<Selection>.from(_selections)
      ..sort((a, b) => b.startLine.compareTo(a.startLine));

    for (var selection in sortedSelections) {
      if (selection.startLine == selection.endLine) {
        // Single line deletion
        String lineContent = buffer.getLine(selection.startLine);
        String newContent = lineContent.substring(0, selection.startColumn) +
            lineContent.substring(selection.endColumn);
        buffer.setLine(selection.startLine, newContent);
      } else {
        // Multi-line deletion
        String startText = buffer
            .getLine(selection.startLine)
            .substring(0, selection.startColumn);
        String endText =
            buffer.getLine(selection.endLine).substring(selection.endColumn);

        // Handle folded regions
        if (buffer.isLineFolded(selection.startLine)) {
          buffer.unfoldLines(selection.startLine);
        }

        // Remove lines in between, accounting for folded regions
        for (int line = selection.endLine; line > selection.startLine; line--) {
          if (buffer.isLineFolded(line)) {
            buffer.unfoldLines(line);
          }
          buffer.removeLine(line);
        }

        // Combine first and last lines
        buffer.setLine(selection.startLine, startText + endText);
      }

      newCursors.add(Cursor(selection.startLine, selection.startColumn));
    }

    clearAll();
    return newCursors;
  }

  List<Cursor> backTab(Buffer buffer, List<Cursor> cursors) {
    List<Cursor> newCursors = [];
    for (int selIndex = 0; selIndex < _selections.length; selIndex++) {
      Selection selection = _selections[selIndex];
      Cursor cursor = cursors[selIndex];

      for (int line = selection.startLine; line <= selection.endLine; line++) {
        if (buffer.getLine(line).startsWith('    ')) {
          buffer.setLine(line, buffer.getLine(line).substring(4));

          if (line == selection.startLine) {
            selection = Selection(
                startLine: selection.startLine,
                endLine: selection.endLine,
                startColumn: math.max(0, selection.startColumn - 4),
                endColumn: math.max(0, selection.endColumn - 4),
                anchorLine: selection.anchorLine,
                anchorColumn: math.max(0, selection.anchorColumn - 4));
            _selections[selIndex] = selection;
          }

          if (line == cursor.line) {
            newCursors.add(Cursor(cursor.line, math.max(0, cursor.column - 4)));
          }
        } else {
          if (line == cursor.line) {
            newCursors.add(cursor);
          }
        }
      }
    }

    return newCursors;
  }

  List<Cursor> insertTab(Buffer buffer, List<Cursor> cursors) {
    List<Cursor> newCursors = [];
    for (int selIndex = 0; selIndex < _selections.length; selIndex++) {
      Selection selection = _selections[selIndex];
      Cursor cursor = cursors[selIndex];

      for (int lineNum = selection.startLine;
          lineNum <= selection.endLine;
          lineNum++) {
        buffer.setLine(lineNum, '    ${buffer.getLine(lineNum)}');

        if (lineNum == selection.startLine) {
          selection = Selection(
              startLine: selection.startLine,
              endLine: selection.endLine,
              startColumn: selection.startColumn + 4,
              endColumn: selection.endColumn + 4,
              anchorColumn: selection.anchorColumn + 4,
              anchorLine: selection.anchorLine);
          _selections[selIndex] = selection;
        }

        if (lineNum == cursor.line) {
          newCursors.add(Cursor(cursor.line, cursor.column + 4));
        }
      }
    }
    return newCursors;
  }

  void selectLine(Buffer buffer, bool extend, int lineNumber) {
    if (extend && _selections.isNotEmpty) {
      // Extend selection to include target line
      Selection currentSelection = _selections.first;
      if (lineNumber < currentSelection.anchorLine) {
        _selections[0] = Selection(
            startLine: lineNumber,
            endLine: currentSelection.anchorLine,
            startColumn: 0,
            endColumn: buffer.getLineLength(currentSelection.anchorLine),
            anchorLine: currentSelection.anchorLine,
            anchorColumn: currentSelection.anchorColumn);
      } else {
        _selections[0] = Selection(
            startLine: currentSelection.anchorLine,
            endLine: lineNumber,
            startColumn: 0,
            endColumn: buffer.getLineLength(lineNumber),
            anchorLine: currentSelection.anchorLine,
            anchorColumn: currentSelection.anchorColumn);
      }
    } else {
      // Select single line
      clearAll();
      _selections.add(Selection(
          startLine: lineNumber,
          endLine: lineNumber,
          startColumn: 0,
          endColumn: buffer.getLineLength(lineNumber),
          anchorLine: lineNumber,
          anchorColumn: 0));
    }
  }

  void addSelection(Selection selection) {
    _selections.add(selection);
  }
}
