import 'dart:math';

import 'package:crystal/core/buffer_manager.dart';

class CursorManager {
  final BufferManager _bufferManager;
  int cursorIndex = 0;
  int cursorLine = 0;
  int targetCursorIndex = 0;

  CursorManager(this._bufferManager);

  void moveTo(int line, int column) {
    cursorLine = line.clamp(0, _bufferManager.lines.length);
    cursorIndex = column.clamp(0, _bufferManager.lines[cursorLine].length);
  }

  void moveLeft() {
    if (cursorIndex > 0) {
      cursorIndex--;
      targetCursorIndex = cursorIndex;
    } else if (cursorLine > 0) {
      cursorLine--;
      cursorIndex = _bufferManager.lines[cursorLine].length;
      targetCursorIndex = cursorIndex;
    }
  }

  void moveRight() {
    if (cursorIndex + 1 > _bufferManager.lines[cursorLine].length &&
        cursorLine + 1 < _bufferManager.lines.length) {
      cursorLine++;
      cursorIndex = 0;
      targetCursorIndex = cursorIndex;
    } else {
      if (cursorLine == _bufferManager.lines.length - 1 &&
          cursorIndex >
              _bufferManager.lines[_bufferManager.lines.length - 1].length -
                  1) {
        return;
      }

      cursorIndex++;
      targetCursorIndex = cursorIndex;
    }
  }

  void moveUp() {
    if (cursorLine - 1 < 0) {
      moveToLineStart();
      return;
    }

    cursorLine--;
    cursorIndex =
        min(targetCursorIndex, _bufferManager.lines[cursorLine].length);
  }

  void moveDown() {
    if (cursorLine + 1 >= _bufferManager.lines.length) {
      moveToLineEnd();
      return;
    }

    cursorLine++;
    cursorIndex =
        min(targetCursorIndex, _bufferManager.lines[cursorLine].length);
  }

  void moveToLineStart() {
    cursorIndex = 0;
    targetCursorIndex = cursorIndex;
  }

  void moveToLineEnd() {
    cursorIndex = _bufferManager.lines[cursorLine].length;
    targetCursorIndex = cursorIndex;
  }
}
