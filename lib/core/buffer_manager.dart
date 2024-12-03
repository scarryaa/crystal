class BufferManager {
  int cursorPosition = 0;
  int cursorLine = 0;
  final List<String> _lines = [''];

  List<String> get lines => List<String>.from(_lines);

  void moveLeft() {
    if (cursorPosition > 0) {
      cursorPosition--;
    } else if (cursorLine > 0) {
      cursorLine--;
      cursorPosition = _lines[cursorLine].length;
    }
  }

  void moveRight() {
    if (cursorPosition > _lines[cursorLine].length) {
      cursorLine++;
      cursorPosition = 0;
    } else if (cursorPosition < _lines[_lines.length].length) {
      cursorPosition++;
    }
  }

  void moveUp() {}

  void moveDown() {}

  void insertCharacter(String char) {
    _lines[cursorLine] = _lines[cursorLine].substring(0, cursorPosition) +
        char +
        _lines[cursorLine].substring(cursorPosition);
    cursorPosition++;
  }

  void insertNewline() {
    _lines.insert(cursorLine + 1, '');
    cursorLine++;
    cursorPosition = 0;
  }

  void delete(int length) {
    if (_validateCursorPositionBeforeDelete() == false) return;

    _adjustCursorPositionBeforeDelete();
    _lines[cursorLine] = _lines[cursorLine]
            .substring(0, cursorPosition - length) +
        _lines[cursorLine].substring(cursorPosition, _lines[cursorLine].length);
    _adjustCursorPositionAfterDelete();
  }

  void deleteForwards(int length) {
    // Check if there is actually content after the cursor
    if (_lines[cursorLine].length > cursorPosition) {
      // Deleting before the end of the line
      if (cursorPosition < _lines[cursorLine].length) {
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
    if (cursorPosition - 1 < 0 && cursorLine == 0) return false;
    return true;
  }

  void _adjustCursorPositionBeforeDelete() {
    // Deleting onto a previous line
    if (cursorPosition - 1 < 0 && cursorLine > 0) {
      cursorLine--;
      cursorPosition = _lines[cursorLine].length;
    }
  }

  void _adjustCursorPositionAfterDelete() {
    if (cursorPosition < 0 && cursorLine > 0) {
      cursorLine--;
      cursorPosition = _lines[cursorLine].length;
    } else {
      cursorPosition--;
    }
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
