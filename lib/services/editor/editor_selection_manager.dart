import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/selection.dart';
import 'package:flutter/material.dart';

class EditorSelectionManager {
  final List<Selection> _selections = [];
  List<Selection> get selections => _selections;

  bool hasSelection() {
    return _selections.isNotEmpty;
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
    for (int i = 0; i < cursors.length; i++) {
      _selections.add(Selection(
          startLine: cursors[i].line,
          endLine: cursors[i].line,
          startColumn: cursors[i].column,
          endColumn: cursors[i].column,
          anchorLine: cursors[i].line,
          anchorColumn: cursors[i].column));
      debugPrint('added selection ${_selections[i]}');
    }
  }

  void updateSelection(List<Cursor> cursors) {
    for (int i = 0; i < cursors.length; i++) {
      Selection currentSelection = _selections[i];
      Cursor currentCursor = cursors[i];

      // Compare currentCursor position with anchor to determine direction
      if (currentCursor.line < currentSelection.anchorLine ||
          (currentCursor.line == currentSelection.anchorLine &&
              currentCursor.column < currentSelection.anchorColumn)) {
        // Selecting backwards
        _selections[i] = Selection(
          startLine: currentCursor.line,
          endLine: currentSelection.anchorLine,
          startColumn: currentCursor.column,
          endColumn: currentSelection.anchorColumn,
          anchorLine: currentSelection.anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
        debugPrint('Selecting backwards: ${_selections[i]}');
      } else {
        // Selecting forwards
        _selections[i] = Selection(
          startLine: currentSelection.anchorLine,
          endLine: currentCursor.line,
          startColumn: currentSelection.anchorColumn,
          endColumn: currentCursor.column,
          anchorLine: currentSelection.anchorLine,
          anchorColumn: currentSelection.anchorColumn,
        );
        debugPrint('Selecting forwards: ${_selections[i]}');
      }
    }
  }

  void clearAll() {
    _selections.clear();
  }

  List<Cursor> deleteSelection(Buffer buffer) {
    List<Cursor> newCursors = [];

    for (var selection in selections) {
      if (selection.startLine == selection.endLine) {
        // Single line deletion
        String newContent = buffer
                .getLine(selection.startLine)
                .substring(0, selection.startColumn) +
            buffer.getLine(selection.startLine).substring(selection.endColumn);
        buffer.setLine(selection.startLine, newContent);
      } else {
        // Multi-line deletion
        String startText = buffer
            .getLine(selection.startLine)
            .substring(0, selection.startColumn);
        String endText =
            buffer.getLine(selection.endLine).substring(selection.endColumn);

        // Combine first and last lines
        buffer.setLine(selection.startLine, startText + endText);

        // Remove lines in between
        for (int i = 0; i < selection.endLine - selection.startLine; i++) {
          buffer.removeLine(selection.startLine + 1);
        }
      }

      newCursors.add(Cursor(selection.startLine, selection.startColumn));
    }

    clearAll();
    return newCursors;
  }

  List<Cursor> backTab(Buffer buffer, List<Cursor> cursors) {
    List<Cursor> newCursors = [];

    for (int i = 0; i < _selections.length; i++) {
      Selection selection = _selections[i];
      Cursor cursor = cursors[i];

      // Remove tab from each line in selection
      for (int line = selection.startLine; line <= selection.endLine; line++) {
        if (buffer.getLine(line).startsWith('    ')) {
          buffer.setLine(line, buffer.getLine(line).substring(4));

          // Adjust selection and cursor columns
          if (line == selection.startLine) {
            selection = Selection(
                startLine: selection.startLine,
                endLine: selection.endLine,
                startColumn: math.max(0, selection.startColumn - 4),
                endColumn: math.max(0, selection.endColumn - 4),
                anchorLine: selection.startLine,
                anchorColumn: math.max(0, selection.startColumn - 4));
          }
          if (line == cursor.line) {
            newCursors.add(Cursor(cursor.line, math.max(0, cursor.column - 4)));
          }
        }
      }
    }

    return newCursors;
  }

  List<Cursor> insertTab(Buffer buffer, List<Cursor> cursors) {
    List<Cursor> newCursors = [];

    for (int i = 0; i < _selections.length; i++) {
      Selection selection = _selections[i];
      Cursor cursor = cursors[i];

      // Add tab to each line in selection
      for (int i = selection.startLine; i <= selection.endLine; i++) {
        buffer.setLine(i, '    ${buffer.getLine(i)}');

        // Adjust selection and cursor columns
        if (i == selection.startLine) {
          selection = Selection(
              startLine: selection.startLine,
              endLine: selection.endLine,
              startColumn: selection.startColumn + 4,
              endColumn: selection.endColumn + 4,
              anchorColumn: selection.startColumn + 4,
              anchorLine: selection.startLine);
        }

        if (i == cursor.line) {
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
        sb.write(buffer
            .getLine(selection.startLine)
            .substring(selection.startColumn, selection.endColumn));
      }

      // First line
      sb.write(
          buffer.getLine(selection.startLine).substring(selection.startColumn));
      sb.write('\n');

      // Middle lines
      for (int i = selection.startLine + 1; i < selection.endLine; i++) {
        sb.write(buffer.getLine(i));
        sb.write('\n');
      }

      // Last line
      sb.write(
          buffer.getLine(selection.endLine).substring(0, selection.endColumn));

      return sb.toString();
    }

    return '';
  }
}
