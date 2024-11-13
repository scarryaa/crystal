import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/selection.dart';
import 'package:flutter/material.dart';

class EditorSelectionManager {
  List<Selection> _selections = [];
  List<Selection> get selections => _selections;

  bool hasSelection() {
    return _selections.isNotEmpty;
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

  void updateSelection(List<Cursor> cursors) {
    for (int i = 0; i < cursors.length; i++) {
      Selection currentSelection = _selections[i];
      Cursor currentCursor = cursors[i];

      // Get actual buffer positions considering folded regions
      int anchorLine = currentSelection.anchorLine;
      int cursorLine = currentCursor.line;

      if (cursorLine < anchorLine ||
          (cursorLine == anchorLine &&
              currentCursor.column < currentSelection.anchorColumn)) {
        // Selecting backwards
        _selections[i] = Selection(
          startLine: cursorLine,
          endLine: anchorLine,
          startColumn: currentCursor.column,
          endColumn: currentSelection.anchorColumn,
          anchorLine: anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
      } else {
        // Selecting forwards
        _selections[i] = Selection(
          startLine: anchorLine,
          endLine: cursorLine,
          startColumn: currentSelection.anchorColumn,
          endColumn: currentCursor.column,
          anchorLine: anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
      }
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
        for (int line = selection.endLine - 1;
            line > selection.startLine;
            line--) {
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

  void selectAll(int endLine, int endColumn) {
    clearAll();
    _selections.add(Selection(
        startLine: 0,
        endLine: endLine,
        startColumn: 0,
        endColumn: endColumn,
        anchorLine: endLine,
        anchorColumn: endColumn));
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

  String getSelectedText(Buffer buffer) {
    StringBuffer sb = StringBuffer();

    for (var selection in _selections) {
      if (selection.startLine == selection.endLine) {
        // Single line selection
        String line = buffer.getLine(selection.startLine);
        sb.write(line.substring(selection.startColumn, selection.endColumn));
        continue;
      }

      // First line
      sb.write(
          buffer.getLine(selection.startLine).substring(selection.startColumn));
      sb.write('\n');

      // Middle lines
      for (int i = selection.startLine + 1; i < selection.endLine; i++) {
        if (buffer.isLineFolded(i)) {
          // Include folded content
          sb.write(buffer.getLine(i));
          sb.write('\n');
          for (var line in buffer.getFoldedContent(i)) {
            sb.write(line);
            sb.write('\n');
          }
          i = buffer.getFoldedRange(i);
        } else {
          sb.write(buffer.getLine(i));
          sb.write('\n');
        }
      }

      // Last line
      sb.write(
          buffer.getLine(selection.endLine).substring(0, selection.endColumn));
    }

    return sb.toString();
  }
}
