class BufferManager {
  final int cursorPosition = 0;
  final int cursorLine = 0;
  final List<String> _lines = ["Hello"];

  List<String> get lines => _lines;

  void insertCharacter(String char) {
    _lines[cursorLine] = _lines[cursorLine].substring(0, cursorPosition) +
        char +
        _lines[cursorLine].substring(cursorPosition);
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
