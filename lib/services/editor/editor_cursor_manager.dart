import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';

class EditorCursorManager {
  final List<Cursor> _cursors = [];
  List<Cursor> get cursors => _cursors;

  void addCursor(Cursor cursor) {
    _cursors.add(cursor);
  }

  void reset() {
    _cursors.clear();
    _cursors.add(Cursor(0, 0));
  }

  void clearAll() {
    _cursors.clear();
  }

  void insertNewLine(Buffer buffer) {
    for (var cursor in _cursors) {
      String currentLine = buffer.getLine(cursor.line);
      String remainingText = currentLine.substring(cursor.column);
      String beforeCursor = currentLine.substring(0, cursor.column);

      // Calculate indentation of current line
      String indentation = '';
      for (int i = 0; i < currentLine.length; i++) {
        if (currentLine[i] == ' ') {
          indentation += ' ';
        } else {
          break;
        }
      }

      // Keep indentation for new line
      buffer.setLine(cursor.line, beforeCursor);
      buffer.insertLine(cursor.line + 1, content: indentation + remainingText);

      cursor.line++;
      cursor.column = indentation.length;
    }
  }

  void moveUp(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.line > 0) {
        cursor.line--;
        cursor.column =
            cursor.column.clamp(0, buffer.getLineLength(cursor.line));
      }
    }
  }

  void moveRight(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.column < buffer.getLineLength(cursor.line)) {
        cursor.column++;
      } else if (cursor.line < buffer.lineCount - 1) {
        cursor.line++;
        cursor.column = 0;
      }
    }
  }

  void moveLeft(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.column > 0) {
        cursor.column--;
      } else if (cursor.line > 0) {
        cursor.line--;
        cursor.column = buffer.getLineLength(cursor.line);
      }
    }
  }

  void moveDown(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.line < buffer.lineCount - 1) {
        cursor.line++;
        cursor.column =
            cursor.column.clamp(0, buffer.getLineLength(cursor.line));
      }
    }
  }

  void setAllCursors(List<Cursor> newCursors) {
    for (int i = 0; i < _cursors.length; i++) {
      _cursors[i].line = newCursors[i].line;
      _cursors[i].column = newCursors[i].column;
    }
  }

  void backspace(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.column > 0) {
        // Check if we're deleting spaces at the start of a line
        String currentLine = buffer.getLine(cursor.line);
        String beforeCursor = currentLine.substring(0, cursor.column);
        if (beforeCursor.endsWith('    ') && beforeCursor.trim().isEmpty) {
          // Delete entire tab (4 spaces)
          buffer.setLine(
              cursor.line,
              currentLine.substring(0, cursor.column - 4) +
                  currentLine.substring(cursor.column));
          cursor.column -= 4;
        } else {
          // Normal single character deletion
          buffer.setLine(
              cursor.line,
              currentLine.substring(0, cursor.column - 1) +
                  currentLine.substring(cursor.column));
          cursor.column--;
        }
      } else if (cursor.line > 0) {
        cursor.column = buffer.getLineLength(cursor.line - 1);
        buffer.setLine(cursor.line - 1,
            buffer.getLine(cursor.line - 1) + buffer.getLine(cursor.line));
        buffer.removeLine(cursor.line);
        cursor.line--;
      }
    }
  }

  void backTab(Buffer buffer) {
    for (var cursor in _cursors) {
      // Remove tab at cursor position if line starts with spaces
      String currentLine = buffer.getLine(cursor.line);
      if (currentLine.startsWith('    ')) {
        buffer.setLine(cursor.line, currentLine.substring(4));
        cursor.column = math.max(0, cursor.column - 4);
      }
    }
  }

  void paste(Buffer buffer, String pastedLines) {
    var splitLines = pastedLines.split('\n');
    for (var cursor in _cursors) {
      if (splitLines.length == 1) {
        // Single line paste
        String newContent =
            buffer.getLine(cursor.line).substring(0, cursor.column) +
                splitLines[0] +
                buffer.getLine(cursor.line).substring(cursor.column);
        buffer.setLine(cursor.line, newContent);
        cursor.column += splitLines[0].length;
      } else {
        // Multi-line paste
        String remainingText =
            buffer.getLine(cursor.line).substring(cursor.column);

        // First line
        buffer.setLine(
            cursor.line,
            buffer.getLine(cursor.line).substring(0, cursor.column) +
                splitLines[0]);

        // Middle lines
        for (int i = 1; i < splitLines.length - 1; i++) {
          buffer.insertLine(cursor.line + i, content: splitLines[i]);
        }

        // Last line
        buffer.insertLine(cursor.line + splitLines.length - 1,
            content: splitLines.last + remainingText);

        cursor.line += splitLines.length - 1;
        cursor.column = splitLines.last.length;
      }
    }
  }

  void delete(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.column < buffer.getLineLength(cursor.line)) {
        String currentLine = buffer.getLine(cursor.line);
        String afterCursor = currentLine.substring(cursor.column);
        if (afterCursor.startsWith('    ') &&
            afterCursor.substring(4).trim().isEmpty) {
          // Delete entire tab (4 spaces)
          buffer.setLine(
              cursor.line,
              currentLine.substring(0, cursor.column) +
                  currentLine.substring(cursor.column + 4));
        } else {
          // Normal single character deletion
          buffer.setLine(
              cursor.line,
              currentLine.substring(0, cursor.column) +
                  currentLine.substring(cursor.column + 1));
        }
      } else if (cursor.line < buffer.lineCount - 1) {
        buffer.setLine(cursor.line,
            buffer.getLine(cursor.line) + buffer.getLine(cursor.line + 1));
        buffer.removeLine(cursor.line + 1);
      }
    }
  }
}
