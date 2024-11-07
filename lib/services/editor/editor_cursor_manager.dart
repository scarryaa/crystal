import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';

class EditorCursorManager {
  List<Cursor> _cursors = [];
  List<Cursor> get cursors => _cursors;

  void addCursor(Cursor cursor) {
    _cursors.add(cursor);
  }

  void removeCursor(Cursor cursor) {
    _cursors.remove(cursor);
  }

  void mergeCursorsIfNeeded() {
    final uniqueCursors = <Cursor>[];

    // Sort cursors by line and column
    _cursors.sort((a, b) {
      if (a.line != b.line) {
        return a.line.compareTo(b.line);
      }
      return a.column.compareTo(b.column);
    });

    for (var cursor in _cursors) {
      // Check if this cursor overlaps with any cursor in uniqueCursors
      bool hasOverlap = uniqueCursors.any((existing) =>
          existing.line == cursor.line && existing.column == cursor.column);

      if (!hasOverlap) {
        uniqueCursors.add(cursor);
      }
    }

    _cursors = uniqueCursors;
  }

  bool cursorExistsAtPosition(int line, int column) {
    return _cursors
        .any((cursor) => cursor.line == line && cursor.column == column);
  }

  void reset() {
    _cursors.clear();
    _cursors.add(Cursor(0, 0));
  }

  void clearAll() {
    _cursors.clear();
  }

  void insertNewLine(Buffer buffer) {
    // Sort cursors from bottom to top to maintain correct positions
    final sortedCursors = List<Cursor>.from(_cursors)
      ..sort((a, b) => b.line.compareTo(a.line));
    for (var cursor in sortedCursors) {
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
      // Update cursor position
      cursor.line += 1;
      cursor.column = indentation.length;

      // Update later cursor positions
      for (var otherCursor in _cursors) {
        if (otherCursor.line > cursor.line) {
          otherCursor.line += 1;
        } else if (otherCursor.line == cursor.line &&
            otherCursor.column > cursor.column) {
          otherCursor.column += 1;
        }
      }
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

    mergeCursorsIfNeeded();
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

    mergeCursorsIfNeeded();
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

    mergeCursorsIfNeeded();
  }

  void moveDown(Buffer buffer) {
    for (var cursor in _cursors) {
      if (cursor.line < buffer.lineCount - 1) {
        cursor.line++;
        cursor.column =
            cursor.column.clamp(0, buffer.getLineLength(cursor.line));
      }
    }

    mergeCursorsIfNeeded();
  }

  void setAllCursors(List<Cursor> newCursors) {
    for (int i = 0; i < _cursors.length; i++) {
      _cursors[i].line = newCursors[i].line;
      _cursors[i].column = newCursors[i].column;
    }

    mergeCursorsIfNeeded();
  }

  void backspace(Buffer buffer) {
    // Sort cursors from bottom to top to maintain correct positions
    final sortedCursors = List<Cursor>.from(_cursors)
      ..sort((a, b) => b.line.compareTo(a.line));

    for (var cursor in sortedCursors) {
      mergeCursorsIfNeeded();

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

      // Update earlier cursor positions
      for (var otherCursor in _cursors) {
        if (otherCursor.line > cursor.line) {
          otherCursor.line -= 1;
        } else if (otherCursor.line == cursor.line &&
            otherCursor.column > cursor.column) {
          otherCursor.column -= 1;
        }
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

    mergeCursorsIfNeeded();
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

    mergeCursorsIfNeeded();
  }
}
