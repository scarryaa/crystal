import 'dart:math' as math;
import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:flutter/material.dart';

class EditorCursorManager extends ChangeNotifier {
  Function(int line, int column)? onCursorChange;
  bool showCaret = true;
  CursorShape cursorShape = CursorShape.bar;
  bool _insertMode = true;
  bool get insertMode => _insertMode;

  List<Cursor> _cursors = [];
  List<Cursor> get cursors => _cursors;

  bool get hasCursors => cursors.isNotEmpty;
  void setCursor(int line, int column) {
    clearAll();
    _cursors.add(Cursor(line, column));
    _notifyCursorChange();
  }

  void toggleInsertMode() {
    _insertMode = !_insertMode;
    // Toggle cursor shape based on mode
    cursorShape = _insertMode ? CursorShape.bar : CursorShape.block;
    notifyListeners();
  }

  void _notifyCursorChange() {
    if (onCursorChange != null && cursors.isNotEmpty) {
      onCursorChange!(cursors[0].line, cursors[0].column);
    }
    notifyListeners();
  }

  int getCursorLine() {
    // Return the line number of the first cursor
    if (cursors.isEmpty) {
      return 0;
    }
    return cursors.first.line;
  }

  void toggleCaret() {
    showCaret = !showCaret;
  }

  void addCursor(Cursor cursor) {
    _cursors.add(cursor);
    _notifyCursorChange();
  }

  void removeCursor(Cursor cursor) {
    _cursors.remove(cursor);
    _notifyCursorChange();
  }

  void moveToLineStart(Buffer buffer) {
    for (var cursor in cursors) {
      final line = buffer.getLine(cursor.line);
      final firstNonWhitespace = line.indexOf(RegExp(r'\S'));
      final targetColumn = firstNonWhitespace == -1 ? 0 : firstNonWhitespace;

      // If already at first non-whitespace, go to start of line
      if (cursor.column == targetColumn && targetColumn > 0) {
        cursor.column = 0;
      } else {
        cursor.column = targetColumn;
      }
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void moveToLineEnd(Buffer buffer) {
    for (var cursor in cursors) {
      cursor.column = buffer.getLineLength(cursor.line);
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void moveToDocumentStart(Buffer buffer) {
    for (var cursor in cursors) {
      cursor.line = 0;
      cursor.column = 0;
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void moveToDocumentEnd(Buffer buffer) {
    for (var cursor in cursors) {
      cursor.line = buffer.lineCount - 1;
      cursor.column = buffer.getLineLength(buffer.lineCount - 1);
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void movePageUp(Buffer buffer, FoldingManager foldingManager) {
    const pageSize = 20; // This should come from scroll state
    for (var cursor in cursors) {
      int targetLine = math.max(0, cursor.line - pageSize);
      while (
          targetLine < cursor.line && foldingManager.isLineHidden(targetLine)) {
        targetLine++;
      }
      cursor.line = targetLine;
      cursor.column = math.min(cursor.column, buffer.getLineLength(targetLine));
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void movePageDown(Buffer buffer, FoldingManager foldingManager) {
    const pageSize = 20; // This should come from scroll state
    final lastLine = buffer.lineCount - 1;
    for (var cursor in cursors) {
      int targetLine = math.min(lastLine, cursor.line + pageSize);
      while (
          targetLine > cursor.line && foldingManager.isLineHidden(targetLine)) {
        targetLine--;
      }
      cursor.line = targetLine;
      cursor.column = math.min(cursor.column, buffer.getLineLength(targetLine));
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
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

  void _moveCursors(Buffer buffer, FoldingManager foldingManager,
      int Function(int, FoldingManager) getNextLine) {
    for (var cursor in cursors) {
      int nextLine = getNextLine(cursor.line, foldingManager);
      if (nextLine >= 0 && nextLine < buffer.lineCount) {
        cursor.line = nextLine;
        cursor.column = min(cursor.column, buffer.getLineLength(nextLine));
      }
    }
    mergeCursorsIfNeeded();
  }

  void moveCursor(int line, int column) {
    clearAll();
    _cursors.add(Cursor(0, 0));
    _cursors[0].line = line;
    _cursors[0].column = column;
  }

  void moveUp(Buffer buffer, FoldingManager foldingManager) {
    _moveCursors(
        buffer, foldingManager, (line, fm) => fm.getPreviousVisibleLine(line));
    _notifyCursorChange();
  }

  void moveDown(Buffer buffer, FoldingManager foldingManager) {
    _moveCursors(
        buffer, foldingManager, (line, fm) => fm.getNextVisibleLine(line));
    _notifyCursorChange();
  }

  void moveLeft(Buffer buffer, FoldingManager foldingManager) {
    for (var cursor in cursors) {
      if (cursor.column > 0) {
        cursor.column--;
      } else if (cursor.line > 0) {
        int prevLine = foldingManager.getPreviousVisibleLine(cursor.line);
        if (prevLine >= 0) {
          cursor.line = prevLine;
          cursor.column = buffer.getLineLength(prevLine);
        }
      }
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void moveRight(Buffer buffer, FoldingManager foldingManager) {
    for (var cursor in cursors) {
      int lineLength = buffer.getLineLength(cursor.line);
      if (cursor.column < lineLength) {
        cursor.column++;
      } else if (cursor.line < buffer.lineCount - 1) {
        int nextLine = foldingManager.getNextVisibleLine(cursor.line);
        if (nextLine < buffer.lineCount) {
          cursor.line = nextLine;
          cursor.column = 0;
        }
      }
    }
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void setAllCursors(List<Cursor> newCursors) {
    for (int i = 0; i < _cursors.length; i++) {
      _cursors[i].line = newCursors[i].line;
      _cursors[i].column = newCursors[i].column;
    }

    mergeCursorsIfNeeded();
    _notifyCursorChange();
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

      for (var otherCursor in _cursors) {
        if (otherCursor.line == cursor.line &&
            otherCursor.column > cursor.column) {
          otherCursor.column -= 1;
        }
      }
    }
    _notifyCursorChange();
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
    _notifyCursorChange();
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
    _notifyCursorChange();
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
    _notifyCursorChange();
  }
}
