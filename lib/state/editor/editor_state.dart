import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  List<Cursor> cursors = [Cursor(0, 0)];
  EditorScrollState scrollState = EditorScrollState();
  Map<Cursor, Cursor> selections = {};

  double getGutterWidth() {
    return math.max((lines.length.toString().length * 10.0) + 20.0, 48.0);
  }

  void addCursor(int line, int column) {
    cursors.add(Cursor(line, column));
    notifyListeners();
  }

  void startSelection(Cursor cursor) {
    selections[cursor] = Cursor(cursor.line, cursor.column);
    notifyListeners();
  }

  void updateSelection(Cursor cursor) {
    if (selections.containsKey(cursor)) {
      selections[cursor]!.line = cursor.line;
      selections[cursor]!.column = cursor.column;
      notifyListeners();
    }
  }

  void clearSelection(Cursor cursor) {
    selections.remove(cursor);
    notifyListeners();
  }

  void clearAllSelections() {
    selections.clear();
    notifyListeners();
  }

  String getSelectedText(Cursor cursor) {
    if (!selections.containsKey(cursor)) return '';

    Cursor start = cursor;
    Cursor end = selections[cursor]!;

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

  void deleteSelection(Cursor cursor) {
    if (!selections.containsKey(cursor)) return;

    Cursor start = cursor;
    Cursor end = selections[cursor]!;

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

    clearSelection(cursor);
    version++;
    notifyListeners();
  }

  void backspace() {
    for (var cursor in cursors) {
      if (selections.containsKey(cursor)) {
        deleteSelection(cursor);
        continue;
      }

      if (cursor.column > 0) {
        lines[cursor.line] =
            lines[cursor.line].substring(0, cursor.column - 1) +
                lines[cursor.line].substring(cursor.column);
        cursor.column--;
      } else if (cursor.line > 0) {
        cursor.column = lines[cursor.line - 1].length;
        lines[cursor.line - 1] += lines[cursor.line];
        lines.removeAt(cursor.line);
        cursor.line--;
      }
    }
    version++;
    notifyListeners();
  }

  void delete() {
    for (var cursor in cursors) {
      if (selections.containsKey(cursor)) {
        deleteSelection(cursor);
        continue;
      }

      if (cursor.column < lines[cursor.line].length) {
        lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
            lines[cursor.line].substring(cursor.column + 1);
      } else if (cursor.line < lines.length - 1) {
        lines[cursor.line] += lines[cursor.line + 1];
        lines.removeAt(cursor.line + 1);
      }
    }
    version++;
    notifyListeners();
  }

  void insertChar(String c) {
    for (var cursor in cursors) {
      if (selections.containsKey(cursor)) {
        deleteSelection(cursor);
      }

      lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
          c +
          lines[cursor.line].substring(cursor.column);
      cursor.column++;
    }
    version++;
    notifyListeners();
  }

  void insertNewLine() {
    for (var cursor in cursors) {
      if (selections.containsKey(cursor)) {
        deleteSelection(cursor);
      }

      String remainingText = lines[cursor.line].substring(cursor.column);
      lines[cursor.line] = lines[cursor.line].substring(0, cursor.column);
      lines.insert(cursor.line + 1, remainingText);
      cursor.line++;
      cursor.column = 0;
    }
    version++;
    notifyListeners();
  }

  void moveCursorDown() {
    for (var cursor in cursors) {
      if (cursor.line < lines.length - 1) {
        cursor.line++;
        cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
      }
    }
    notifyListeners();
  }

  void moveCursorLeft() {
    for (var cursor in cursors) {
      if (cursor.column > 0) {
        cursor.column--;
      } else if (cursor.line > 0) {
        cursor.line--;
        cursor.column = lines[cursor.line].length;
      }
    }
    notifyListeners();
  }

  void moveCursorRight() {
    for (var cursor in cursors) {
      if (cursor.column < lines[cursor.line].length) {
        cursor.column++;
      } else if (cursor.line < lines.length - 1) {
        cursor.line++;
        cursor.column = 0;
      }
    }
    notifyListeners();
  }

  void moveCursorUp() {
    for (var cursor in cursors) {
      if (cursor.line > 0) {
        cursor.line--;
        cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
      }
    }
    notifyListeners();
  }

  void removeCursor(int index) {
    if (cursors.length > 1) {
      var cursor = cursors[index];
      selections.remove(cursor);
      cursors.removeAt(index);
      notifyListeners();
    }
  }

  void updateVerticalScrollOffset(double offset) {
    scrollState.updateVerticalScrollOffset(offset);
  }

  void updateHorizontalScrollOffset(double offset) {
    scrollState.updateHorizontalScrollOffset(offset);
  }
}
