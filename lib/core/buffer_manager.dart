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

  @override
  String toString() {
    return _lines.join('\n');
  }
}
