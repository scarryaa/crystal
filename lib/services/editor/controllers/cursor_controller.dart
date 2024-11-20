import 'dart:math' as math;

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/selection_manager.dart';
import 'package:flutter/material.dart';

class CursorController extends ChangeNotifier {
  final Buffer buffer;
  final FoldingManager foldingManager;
  final SelectionManager selectionManager;

  Function(int line, int column)? onCursorChange;
  bool showCaret = true;
  CursorShape cursorShape = CursorShape.bar;
  bool _insertMode = true;
  bool get insertMode => _insertMode;

  List<Cursor> _cursors = [];
  List<Cursor> get cursors => _cursors;
  bool get hasCursors => cursors.isNotEmpty;

  CursorController({
    required this.buffer,
    required this.foldingManager,
    required this.selectionManager,
  }) {
    reset();
  }

  // Basic cursor operations
  void setCursor(int line, int column) {
    clearAll();
    _cursors.add(Cursor(line, column));
    _notifyCursorChange();
  }

  void toggleInsertMode() {
    _insertMode = !_insertMode;
    cursorShape = _insertMode ? CursorShape.bar : CursorShape.block;
    notifyListeners();
  }

  void toggleCaret() {
    showCaret = !showCaret;
    notifyListeners();
  }

  // Movement operations with selection support
  void _handleMovement(bool isShiftPressed, void Function() moveFunction) {
    if (!selectionManager.hasSelection() && isShiftPressed) {
      selectionManager.startSelection(_cursors);
    }

    moveFunction();

    if (isShiftPressed) {
      selectionManager.updateSelection(_cursors);
    } else {
      selectionManager.clearAll();
    }
    notifyListeners();
  }

  void moveCursorToLineStart(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveToLineStart(buffer));
  }

  void moveCursorToLineEnd(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveToLineEnd(buffer));
  }

  void moveCursorToDocumentStart(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveToDocumentStart(buffer));
  }

  void moveCursorToDocumentEnd(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveToDocumentEnd(buffer));
  }

  void moveCursorPageUp(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => movePageUp(buffer, foldingManager));
  }

  void moveCursorPageDown(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => movePageDown(buffer, foldingManager));
  }

  void moveCursorUp(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveUp(buffer, foldingManager));
  }

  void moveCursorDown(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveDown(buffer, foldingManager));
  }

  void moveCursorLeft(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveLeft(buffer, foldingManager));
  }

  void moveCursorRight(bool isShiftPressed) {
    _handleMovement(isShiftPressed, () => moveRight(buffer, foldingManager));
  }

  // Basic movement implementations
  void moveToLineStart(Buffer buffer) {
    for (var cursor in cursors) {
      final line = buffer.getLine(cursor.line);
      final firstNonWhitespace = line.indexOf(RegExp(r'\S'));
      final targetColumn = firstNonWhitespace == -1 ? 0 : firstNonWhitespace;
      cursor.column =
          cursor.column == targetColumn && targetColumn > 0 ? 0 : targetColumn;
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

  void moveUp(Buffer buffer, FoldingManager foldingManager) {
    _moveCursors(
        buffer, foldingManager, (line, fm) => fm.getPreviousVisibleLine(line));
    _notifyCursorChange();
  }

  void moveCursor(int line, int col) {
    clearAll();
    _cursors.add(Cursor(line, col));
    _notifyCursorChange();
  }

  void _moveCursors(Buffer buffer, FoldingManager foldingManager,
      int Function(int, FoldingManager) getNextLine) {
    for (var cursor in cursors) {
      int nextLine = getNextLine(cursor.line, foldingManager);
      if (nextLine >= 0 && nextLine < buffer.lineCount) {
        cursor.line = nextLine;
        cursor.column = math.min(cursor.column, buffer.getLineLength(nextLine));
      }
    }
    mergeCursorsIfNeeded();
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

  // Editing operations
  void insertNewLine(Buffer buffer) {
    final sortedCursors = List<Cursor>.from(_cursors)
      ..sort((a, b) => b.line.compareTo(a.line));

    for (var cursor in sortedCursors) {
      String currentLine = buffer.getLine(cursor.line);
      String remainingText = currentLine.substring(cursor.column);
      String beforeCursor = currentLine.substring(0, cursor.column);

      String indentation = RegExp(r'^\s*').stringMatch(currentLine) ?? '';

      buffer.setLine(cursor.line, beforeCursor);
      buffer.insertLine(cursor.line + 1, content: indentation + remainingText);

      cursor.line += 1;
      cursor.column = indentation.length;

      _updateOtherCursorsAfterNewLine(cursor);
    }
    _notifyCursorChange();
  }

  void _updateOtherCursorsAfterNewLine(Cursor currentCursor) {
    for (var otherCursor in _cursors) {
      if (otherCursor != currentCursor &&
          otherCursor.line >= currentCursor.line) {
        otherCursor.line += 1;
      }
    }
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

  // Utility methods
  void setAllCursors(List<Cursor> newCursors) {
    _cursors.clear();
    _cursors.addAll(newCursors);
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void addCursor(int line, int column) {
    final newCursor = Cursor(line, column);
    _cursors.add(newCursor);
    mergeCursorsIfNeeded();
    _notifyCursorChange();
  }

  void removeCursor(int line, int column) {
    _cursors.removeWhere(
        (cursor) => cursor.line == line && cursor.column == column);

    if (_cursors.isEmpty) {
      _cursors.add(Cursor(0, 0));
    }
    _notifyCursorChange();
  }

  void _notifyCursorChange() {
    if (onCursorChange != null && cursors.isNotEmpty) {
      onCursorChange!(cursors[0].line, cursors[0].column);
    }
    notifyListeners();
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

  void reset() {
    _cursors.clear();
    _cursors.add(Cursor(0, 0));
  }

  void clearAll() {
    _cursors.clear();
  }

  int getCursorLine() {
    return cursors.isEmpty ? 0 : cursors.first.line;
  }

  bool cursorExistsAtPosition(int line, int column) {
    return _cursors
        .any((cursor) => cursor.line == line && cursor.column == column);
  }
}
