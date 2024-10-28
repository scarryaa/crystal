import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  Cursor cursor = Cursor(0, 0);
  EditorScrollState scrollState = EditorScrollState();
  Selection? selection;
  int? anchorLine;
  int? anchorColumn;

  double getGutterWidth() {
    return math.max((lines.length.toString().length * 10.0) + 20.0, 48.0);
  }

  void startSelection() {
    // Store the anchor point when starting selection
    anchorLine = cursor.line;
    anchorColumn = cursor.column;

    selection = Selection(
        startLine: cursor.line,
        endLine: cursor.line,
        startColumn: cursor.column,
        endColumn: cursor.column);
  }

  void updateSelection() {
    if (selection == null || anchorLine == null || anchorColumn == null) return;

    // Compare cursor position with anchor to determine direction
    if (cursor.line < anchorLine! ||
        (cursor.line == anchorLine! && cursor.column < anchorColumn!)) {
      // Selecting backwards
      selection = Selection(
          startLine: cursor.line,
          endLine: anchorLine!,
          startColumn: cursor.column,
          endColumn: anchorColumn!);
    } else {
      // Selecting forwards
      selection = Selection(
          startLine: anchorLine!,
          endLine: cursor.line,
          startColumn: anchorColumn!,
          endColumn: cursor.column);
    }
  }

  void clearSelection() {
    selection = null;
    anchorLine = null;
    anchorColumn = null;
    notifyListeners();
  }

  void selectAll() {
    anchorLine = lines.length - 1;
    anchorColumn = lines.last.length;
    cursor.line = 0;
    cursor.column = 0;
    selection = Selection(
        startLine: 0,
        endLine: lines.length - 1,
        startColumn: 0,
        endColumn: lines.last.length);
    notifyListeners();
  }

  String getSelectedText() {
    if (selection == null) return '';
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line selection
      return lines[_selection.startLine]
          .substring(_selection.startColumn, _selection.endColumn);
    }

    // Multi-line selection
    StringBuffer result = StringBuffer();

    // First line
    result.write(lines[_selection.startLine].substring(_selection.startColumn));
    result.write('\n');

    // Middle lines
    for (int i = _selection.startLine + 1; i < _selection.endLine; i++) {
      result.write(lines[i]);
      result.write('\n');
    }

    // Last line
    result.write(lines[_selection.endLine].substring(0, _selection.endColumn));

    return result.toString();
  }

  void deleteSelection() {
    if (selection == null) return;
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line deletion
      lines[_selection.startLine] =
          lines[_selection.startLine].substring(0, _selection.startColumn) +
              lines[_selection.startLine].substring(_selection.endColumn);
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    } else {
      // Multi-line deletion
      String startText =
          lines[_selection.startLine].substring(0, _selection.startColumn);
      String endText =
          lines[_selection.endLine].substring(_selection.endColumn);

      // Combine first and last lines
      lines[_selection.startLine] = startText + endText;

      // Remove lines in between
      for (int i = 0; i < _selection.endLine - _selection.startLine; i++) {
        lines.removeAt(_selection.startLine + 1);
      }

      // Update cursor position
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    }

    clearSelection();
    version++;
    notifyListeners();
  }

  void backspace() {
    if (selection != null) {
      deleteSelection();
      return;
    }

    if (cursor.column > 0) {
      lines[cursor.line] = lines[cursor.line].substring(0, cursor.column - 1) +
          lines[cursor.line].substring(cursor.column);
      cursor.column--;
    } else if (cursor.line > 0) {
      cursor.column = lines[cursor.line - 1].length;
      lines[cursor.line - 1] += lines[cursor.line];
      lines.removeAt(cursor.line);
      cursor.line--;
    }
    version++;
    notifyListeners();
  }

  void delete() {
    if (selection != null) {
      deleteSelection();
      return;
    }

    if (cursor.column < lines[cursor.line].length) {
      lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
          lines[cursor.line].substring(cursor.column + 1);
    } else if (cursor.line < lines.length - 1) {
      lines[cursor.line] += lines[cursor.line + 1];
      lines.removeAt(cursor.line + 1);
    }
    version++;
    notifyListeners();
  }

  void insertChar(String c) {
    if (selection != null) {
      deleteSelection();
    }

    lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
        c +
        lines[cursor.line].substring(cursor.column);
    cursor.column++;
    version++;
    notifyListeners();
  }

  void insertNewLine() {
    if (selection != null) {
      deleteSelection();
    }

    String remainingText = lines[cursor.line].substring(cursor.column);
    lines[cursor.line] = lines[cursor.line].substring(0, cursor.column);
    lines.insert(cursor.line + 1, remainingText);
    cursor.line++;
    cursor.column = 0;
    version++;
    notifyListeners();
  }

  void moveCursorDown(bool isShiftPressed) {
    if (cursor.line < lines.length - 1) {
      if (selection == null && isShiftPressed) {
        startSelection();
      }

      cursor.line++;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorLeft(bool isShiftPressed) {
    if (selection == null && isShiftPressed) {
      startSelection();
    }

    if (cursor.column > 0) {
      cursor.column--;
    } else if (cursor.line > 0) {
      cursor.line--;
      cursor.column = lines[cursor.line].length;
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorRight(bool isShiftPressed) {
    if (selection == null && isShiftPressed) {
      startSelection();
    }

    if (cursor.column < lines[cursor.line].length) {
      cursor.column++;
    } else if (cursor.line < lines.length - 1) {
      cursor.line++;
      cursor.column = 0;
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    if (cursor.line > 0) {
      if (selection == null && isShiftPressed) {
        startSelection();
      }

      cursor.line--;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void updateVerticalScrollOffset(double offset) {
    scrollState.updateVerticalScrollOffset(offset);
  }

  void updateHorizontalScrollOffset(double offset) {
    scrollState.updateHorizontalScrollOffset(offset);
  }
}
