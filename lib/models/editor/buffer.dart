class Buffer {
  int _version = 1;
  List<String> _lines = [''];
  String _originalContent = '';

  int get version => _version;
  bool get isDirty => _originalContent != lines.join('\n');
  List<String> get lines => _lines;
  int get lineCount => _lines.length;
  bool get isEmpty => _lines.isEmpty;
  String get content => _lines.join('\n');

  int getLineLength(int lineNumber) => _lines[lineNumber].length;

  String getLine(int lineNumber) => _lines[lineNumber];

  void incrementVersion() => _version++;

  void removeLine(int lineNumber) {
    _lines.removeAt(lineNumber);
  }

  void setContent(String content) {
    // Split content into lines and update the editor state
    _lines = content.split('\n');
    if (lines.isEmpty) {
      _lines = [''];
    }

    incrementVersion();
    _originalContent = content;
  }

  void replace(int lineNumber, int index, int length, String newTerm) {
    _lines[lineNumber] = _lines[lineNumber].substring(0, index) +
        newTerm +
        _lines[lineNumber].substring(index + length);
  }

  void setOriginalContent(String content) {
    _originalContent = content;
  }

  void setLine(int lineNumber, String content) {
    _lines[lineNumber] = content;
  }

  void insertLine(int lineNumber, {String content = ''}) {
    lines.insert(lineNumber, content);
    incrementVersion();
  }
}
