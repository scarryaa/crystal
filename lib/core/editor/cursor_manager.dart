import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:flutter/material.dart';

class CursorManager extends ChangeNotifier {
  final BufferManager _bufferManager;
  final Set<Cursor> uniqueCursors = {};
  List<List<Cursor>> layers = [
    [Cursor(line: 0, index: 0)]
  ];
  Cursor? _anchorCursor;

  int targetCursorIndex = 0;

  CursorManager(this._bufferManager) {
    _anchorCursor = layers[0].first;
  }

  Cursor get anchorCursor => _anchorCursor ?? layers[0].first;

  Cursor? firstCursor() {
    if (layers[0].isEmpty) return null;
    return layers[0].first;
  }

  Cursor getCursor(int index, {int layer = 0}) {
    return layers[layer][index];
  }

  void setAnchorCursor(Cursor cursor) {
    _anchorCursor = cursor;
    if (!layers[0].contains(cursor)) {
      addCursor(cursor);
    }
    notifyListeners();
  }

  void clearCursors({bool keepAnchor = true, int layer = 0}) {
    if (keepAnchor) {
      layers[layer] = [_anchorCursor ?? Cursor(line: 0, index: 0)];
    } else {
      layers[layer] = [];
    }
    uniqueCursors.clear();
    notifyListeners();
  }

  void addCursor(Cursor cursor, {int layer = 0}) {
    // Set as anchor if this is the first cursor
    if (layers[layer].isEmpty) {
      _anchorCursor = cursor;
    }
    layers[layer].add(cursor);
    sortCursors();
    notifyListeners();
  }

  void removeCursor(Cursor cursor, {bool keepAnchor = true, int layer = 0}) {
    // Don't remove if it's the anchor cursor
    if (cursor == _anchorCursor && keepAnchor) {
      return;
    }
    layers[layer].remove(cursor);
    notifyListeners();
  }

  void removeCursorAt(int index, {int layer = 0}) {
    if (index >= 0 && index < layers[layer].length) {
      layers[layer].removeAt(index);
      notifyListeners();
    }
  }

  void moveTo(int index, int line, int column, {int layer = 0}) {
    layers[layer][index].line = line.clamp(0, _bufferManager.lines.length - 1);
    layers[layer][index].index =
        column.clamp(0, _bufferManager.lines[layers[layer][index].line].length);
    targetCursorIndex = column;

    mergeCursorsIfNeeded();
    notifyListeners();
  }

  void sortCursors({bool reverse = false}) {
    // Sort cursors by line and index
    for (var layer in layers) {
      layer.sort((c1, c2) {
        if (c1.line != c2.line) {
          if (reverse) return c1.line > c2.line ? -1 : 1;
          return c1.line > c2.line ? 1 : -1;
        }
        if (reverse) return c1.index > c2.index ? -1 : 1;
        return c1.index > c2.index ? 1 : -1;
      });
    }
  }

  Cursor? findClosestCursor(int line, int index, int numberOfLines,
      {int layer = 0}) {
    sortCursors();

    int low = 0;
    int high = layers[layer].length - 1;
    final Cursor target = Cursor(line: line, index: index);
    Cursor? closest;

    while (low <= high) {
      final int mid = low + (high - low) ~/ 2;

      if (layers[layer][mid] == target) {
        return layers[layer][mid];
      }

      if (closest == null ||
          isCursorCloser(layers[layer][mid], closest, target)) {
        closest = layers[layer][mid];
      }

      if (layers[layer][mid].line < target.line ||
          (layers[layer][mid].line == target.line &&
              layers[layer][mid].index < target.index)) {
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }

    return closest;
  }

  bool isCursorCloser(Cursor a, Cursor b, Cursor target) {
    final int distA =
        (a.line - target.line).abs() * 1000 + (a.index - target.index).abs();
    final int distB =
        (b.line - target.line).abs() * 1000 + (b.index - target.index).abs();
    return distA < distB;
  }

  List<Cursor> findCursorsWithinBounds(
      int startLine, int endLine, int startIndex, int endIndex,
      {int layer = 0}) {
    return layers[layer]
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
    for (var layer in layers) {
      uniqueCursors.addAll(layer);
      layer = uniqueCursors.toList();
      uniqueCursors.clear();
    }
  }

  void moveLeft({int layer = 0}) {
    for (var cursor in layers[layer]) {
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

  void moveRight({int layer = 0}) {
    for (var cursor in layers[layer]) {
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

  void moveUp({int layer = 0}) {
    for (var cursor in layers[layer]) {
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

  void moveDown({int layer = 0}) {
    for (var cursor in layers[layer]) {
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

  void moveToLineStart({int layer = 0}) {
    for (var cursor in layers[layer]) {
      cursor.index = 0;
      targetCursorIndex = cursor.index;
    }
    notifyListeners();
  }

  void moveToLineEnd({int layer = 0}) {
    for (var cursor in layers[layer]) {
      cursor.index = _bufferManager.lines[cursor.line].length;
      targetCursorIndex = cursor.index;
    }
    notifyListeners();
  }

  void mergeAllLayersToFirst() {
    if (layers.length <= 1) return;

    for (int i = 1; i < layers.length; i++) {
      layers[0].addAll(layers[i]);
    }

    // Keep only the first layer
    layers.removeRange(1, layers.length);

    notifyListeners();
  }
}
