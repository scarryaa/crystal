import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  Cursor cursor = Cursor(0, 0);
  EditorScrollState scrollState = EditorScrollState();
  Cursor? selection;

  double getGutterWidth() {
    return math.max((lines.length.toString().length * 10.0) + 20.0, 48.0);
  }

  void startSelection() {
    selection = Cursor(cursor.line, cursor.column);
    notifyListeners();
  }

  void updateSelection() {
    if (selection != null) {
      selection!.line = cursor.line;
      selection!.column = cursor.column;
      notifyListeners();
    }
  }

  void clearSelection() {
    selection = null;
    notifyListeners();
  }

  void selectAll() {
    selection = Cursor(lines.length - 1, lines.last.length);
    cursor.line = 0;
    cursor.column = 0;
    notifyListeners();
  }

  String getSelectedText() {
    if (selection == null) return '';

    Cursor start = cursor;
    Cursor end = selection!;

    if (start.line > end.line ||
        (start.line == end.line && start.column > end.column)) {
      var temp = start;
      start = end;
      end = temp;
    }

    if (start.line == end.line) {
      return lines[start.line].substring(start.column, end.column);
    }

    StringBuffer result = StringBuffer();
    result.write(lines[start.line].substring(start.column));
    result.write('\n');

    for (int i = start.line + 1; i < end.line; i++) {
      result.write(lines[i]);
      result.write('\n');
    }

    result.write(lines[end.line].substring(0, end.column));
    return result.toString();
  }

  void deleteSelection() {
    if (selection == null) return;

    Cursor start = cursor;
    Cursor end = selection!;

    if (start.line > end.line ||
        (start.line == end.line && start.column > end.column)) {
      var temp = start;
      start = end;
      end = temp;
    }

    if (start.line == end.line) {
      lines[start.line] = lines[start.line].substring(0, start.column) +
          lines[start.line].substring(end.column);
      cursor.column = start.column;
    } else {
      String startText = lines[start.line].substring(0, start.column);
      String endText = lines[end.line].substring(end.column);
      lines[start.line] = startText + endText;

      for (int i = 0; i < end.line - start.line; i++) {
        lines.removeAt(start.line + 1);
      }

      cursor.line = start.line;
      cursor.column = start.column;
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
      cursor.line++;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
      if (selection == null && isShiftPressed) {
        startSelection();
      } else if (isShiftPressed) {
        updateSelection();
      }
    }
    if (!isShiftPressed) {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorLeft(bool isShiftPressed) {
    if (cursor.column > 0) {
      cursor.column--;
    } else if (cursor.line > 0) {
      cursor.line--;
      cursor.column = lines[cursor.line].length;
    }
    if (selection == null && isShiftPressed) {
      startSelection();
    } else if (isShiftPressed) {
      updateSelection();
    }
    if (!isShiftPressed) {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorRight(bool isShiftPressed) {
    if (cursor.column < lines[cursor.line].length) {
      cursor.column++;
    } else if (cursor.line < lines.length - 1) {
      cursor.line++;
      cursor.column = 0;
    }
    if (selection == null && isShiftPressed) {
      startSelection();
    } else if (isShiftPressed) {
      updateSelection();
    }
    if (!isShiftPressed) {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    if (cursor.line > 0) {
      cursor.line--;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
      if (selection == null && isShiftPressed) {
        startSelection();
      } else if (isShiftPressed) {
        updateSelection();
      }
    }
    if (!isShiftPressed) {
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
