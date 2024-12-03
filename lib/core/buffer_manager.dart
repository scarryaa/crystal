class BufferManager {
  int cursorPosition = 0;
  int cursorLine = 0;
  final List<String> _lines = [''];

  List<String> get lines => List<String>.from(_lines);

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
    _lines[cursorLine] = _lines[cursorLine].substring(0,
        cursorPosition - length < 0 ? cursorPosition : cursorPosition - length);
    _adjustCursorPositionAfterDelete();
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
