import 'package:crystal/models/cursor.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  List<Cursor> cursors = [Cursor(0, 0)];
  EditorScrollState scrollState = EditorScrollState();

  void addCursor(int line, int column) {
    cursors.add(Cursor(line, column));
    notifyListeners();
  }

  void backspace() {
    for (var cursor in cursors) {
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
      cursors.removeAt(index);
      notifyListeners();
    }
  }
}
