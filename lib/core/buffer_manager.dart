import 'dart:math';

class BufferManager {
  int cursorIndex = 0;
  int cursorLine = 0;
  int targetCursorIndex = 0;
  final List<String> _lines = [''];

  List<String> get lines => List<String>.from(_lines);

  void moveLeft() {
    if (cursorIndex > 0) {
      cursorIndex--;
      targetCursorIndex = cursorIndex;
    } else if (cursorLine > 0) {
      cursorLine--;
      cursorIndex = _lines[cursorLine].length;
      targetCursorIndex = cursorIndex;
    }
  }

  void moveRight() {
    if (cursorIndex + 1 > _lines[cursorLine].length &&
        cursorLine + 1 < _lines.length) {
      cursorLine++;
      cursorIndex = 0;
      targetCursorIndex = cursorIndex;
    } else {
      if (cursorLine == _lines.length - 1 &&
          cursorIndex > _lines[_lines.length - 1].length - 1) return;

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
    cursorIndex = min(targetCursorIndex, _lines[cursorLine].length);
  }

  void moveDown() {
    if (cursorLine + 1 >= _lines.length) {
      moveToLineEnd();
      return;
    }

    cursorLine++;
    cursorIndex = min(targetCursorIndex, _lines[cursorLine].length);
  }

  void moveToLineStart() {
    cursorIndex = 0;
    targetCursorIndex = cursorIndex;
  }

  void moveToLineEnd() {
    cursorIndex = _lines[cursorLine].length;
    targetCursorIndex = cursorIndex;
  }

  void insertCharacter(String char) {
    _lines[cursorLine] = _lines[cursorLine].substring(0, cursorIndex) +
        char +
        _lines[cursorLine].substring(cursorIndex);
    cursorIndex++;
    targetCursorIndex = cursorIndex;
  }

  void insertNewline() {
    _lines.insert(cursorLine + 1, '');
    cursorLine++;
    cursorIndex = 0;
    targetCursorIndex = cursorIndex;
  }

  void delete(int length) {
    if (_validateCursorPositionBeforeDelete() == false) return;

    _adjustCursorPositionBeforeDelete();
    _lines[cursorLine] = _lines[cursorLine].substring(0, cursorIndex - length) +
        _lines[cursorLine].substring(cursorIndex, _lines[cursorLine].length);
    _adjustCursorPositionAfterDelete();
  }

  void deleteForwards(int length) {
    // Check if there is actually content after the cursor
    if (_lines[cursorLine].length > cursorIndex) {
      // Deleting before the end of the line
      if (cursorIndex < _lines[cursorLine].length) {
        _lines[cursorLine] =
            _lines[cursorLine].substring(0, _lines[cursorLine].length - length);
        // Deleting at the end of the line
      } else {
        _lines[cursorLine + 1] = _lines[cursorLine + 1]
            .substring(0, _lines[cursorLine + 1].length - length);
      }
    }
  }

  bool _validateCursorPositionBeforeDelete() {
    if (cursorIndex - 1 < 0 && cursorLine == 0) return false;
    return true;
  }

  void _adjustCursorPositionBeforeDelete() {
    // Deleting onto a previous line
    if (cursorIndex - 1 < 0 && cursorLine > 0) {
      cursorLine--;
      cursorIndex = _lines[cursorLine].length;
      targetCursorIndex = cursorIndex;
    }
  }

  void _adjustCursorPositionAfterDelete() {
    if (cursorIndex < 0 && cursorLine > 0) {
      cursorLine--;
      cursorIndex = _lines[cursorLine].length;
      targetCursorIndex = cursorIndex;
    } else {
      cursorIndex--;
      targetCursorIndex = cursorIndex;
    }
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
