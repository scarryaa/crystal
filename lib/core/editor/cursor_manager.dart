import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:flutter/material.dart';

class CursorManager extends ChangeNotifier {
  final BufferManager _bufferManager;
  final Set<Cursor> uniqueCursors = {};
  List<Cursor> cursors = [Cursor(line: 0, index: 0)];
  Cursor? _anchorCursor;

  int targetCursorIndex = 0;

  CursorManager(this._bufferManager) {
    _anchorCursor = cursors.first;
  }

  Cursor get anchorCursor => _anchorCursor ?? cursors.first;

  Cursor firstCursor() {
    if (cursors.isEmpty) {
      addCursor(Cursor(line: 0, index: 0));
    }
    return cursors.first;
  }

  Cursor getCursor(int index) {
    return cursors[index];
  }

  void setAnchorCursor(Cursor cursor) {
    _anchorCursor = cursor;
    if (!cursors.contains(cursor)) {
      addCursor(cursor);
    }
    notifyListeners();
  }

  void clearCursors({bool keepAnchor = true}) {
    if (keepAnchor) {
      cursors = [_anchorCursor ?? Cursor(line: 0, index: 0)];
    } else {
      cursors = [];
    }
    uniqueCursors.clear();
    notifyListeners();
  }

  void addCursor(Cursor cursor) {
    // Set as anchor if this is the first cursor
    if (cursors.isEmpty) {
      _anchorCursor = cursor;
    }
    cursors.add(cursor);
    sortCursors();
    notifyListeners();
  }

  void removeCursor(Cursor cursor, {bool keepAnchor = true}) {
    // Don't remove if it's the anchor cursor
    if (cursor == _anchorCursor && keepAnchor) {
      return;
    }
    cursors.remove(cursor);
    notifyListeners();
  }

  void removeCursorAt(int index) {
    if (index >= 0 && index < cursors.length) {
      cursors.removeAt(index);
      notifyListeners();
    }
  }

  void moveTo(int index, int line, int column) {
    cursors[index].line = line.clamp(0, _bufferManager.lines.length - 1);
    cursors[index].index =
        column.clamp(0, _bufferManager.lines[cursors[index].line].length);
    targetCursorIndex = column;

    mergeCursorsIfNeeded();
    notifyListeners();
  }

  void sortCursors({bool reverse = false}) {
    // Sort cursors by line and index
    cursors.sort((c1, c2) {
      if (c1.line != c2.line) {
        if (reverse) return c1.line > c2.line ? -1 : 1;
        return c1.line > c2.line ? 1 : -1;
      }
      if (reverse) return c1.index > c2.index ? -1 : 1;
      return c1.index > c2.index ? 1 : -1;
    });
  }

  List<Cursor> findCursorsWithinBounds(
      int startLine, int endLine, int startIndex, int endIndex) {
    return cursors
        .where((c) =>
            // Single line selection
            (c.line == startLine &&
                c.line == endLine &&
                c.index >= startIndex &&
                c.index <= endIndex) ||
            // First line of multi-line selection
            (c.line == startLine &&
                c.line < endLine &&
                c.index >= startIndex) ||
            // Last line of multi-line selection
            (c.line == endLine && c.line > startLine && c.index <= endIndex) ||
            // Lines in between start and end
            (c.line > startLine && c.line < endLine))
        .toList();
  }

  void mergeCursorsIfNeeded() {
    uniqueCursors.addAll(cursors);
    cursors = uniqueCursors.toList();
    uniqueCursors.clear();
  }

  void moveLeft() {
    for (var cursor in cursors) {
      if (cursor.index > 0) {
        cursor.index--;
        targetCursorIndex = cursor.index;
      } else if (cursor.line > 0) {
        cursor.line--;
        cursor.index = _bufferManager.lines[cursor.line].length;
        targetCursorIndex = cursor.index;
      }
    }
    notifyListeners();
  }

  void moveRight() {
    for (var cursor in cursors) {
      if (cursor.index + 1 > _bufferManager.lines[cursor.line].length &&
          cursor.line + 1 < _bufferManager.lines.length) {
        cursor.line++;
        cursor.index = 0;
        targetCursorIndex = cursor.index;
      } else {
        if (cursor.line == _bufferManager.lines.length - 1 &&
            cursor.index >
                _bufferManager.lines[_bufferManager.lines.length - 1].length -
                    1) {
          return;
        }

        cursor.index++;
        targetCursorIndex = cursor.index;
      }
    }
    notifyListeners();
  }

  void moveUp() {
    for (var cursor in cursors) {
      if (cursor.line - 1 < 0) {
        moveToLineStart();
        return;
      }

      cursor.line--;
      cursor.index =
          min(targetCursorIndex, _bufferManager.lines[cursor.line].length);
    }
    notifyListeners();
  }

  void moveDown() {
    for (var cursor in cursors) {
      if (cursor.line + 1 >= _bufferManager.lines.length) {
        moveToLineEnd();
        return;
      }

      cursor.line++;
      cursor.index =
          min(targetCursorIndex, _bufferManager.lines[cursor.line].length);
    }
    notifyListeners();
  }

  void moveToLineStart() {
    for (var cursor in cursors) {
      cursor.index = 0;
      targetCursorIndex = cursor.index;
    }
    notifyListeners();
  }

  void moveToLineEnd() {
    for (var cursor in cursors) {
      cursor.index = _bufferManager.lines[cursor.line].length;
      targetCursorIndex = cursor.index;
    }
    notifyListeners();
  }
}
