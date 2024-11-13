class Buffer {
  int _version = 1;
  List<String> _lines = [''];
  String _originalContent = '';
  final Map<int, int> _foldedRanges = {};

  int get version => _version;
  bool get isDirty {
    StringBuffer originalBuffer = StringBuffer();
    List<String> originalLines = _originalContent.split('\n');
    int currentLine = 0;

    while (currentLine < originalLines.length) {
      originalBuffer.writeln(originalLines[currentLine]);
      if (isLineFolded(currentLine)) {
        // Skip folded lines
        currentLine = _foldedRanges[currentLine]! + 1;
      } else {
        currentLine++;
      }
    }

    String processedOriginal = originalBuffer.toString().trimRight();
    return processedOriginal != content;
  }

  List<String> get lines => _lines;
  int get lineCount => _lines.length;
  bool get isEmpty => _lines.isEmpty;

  String get content {
    StringBuffer buffer = StringBuffer();
    int currentLine = 0;

    while (currentLine < _lines.length) {
      buffer.writeln(_lines[currentLine]);
      if (isLineFolded(currentLine)) {
        // Skip folded lines
        currentLine = _foldedRanges[currentLine]! + 1;
      } else {
        currentLine++;
      }
    }

    return buffer.toString().trimRight();
  }

  Map<int, int> get foldedRanges => _foldedRanges;

  bool isLineFolded(int line) => _foldedRanges.containsKey(line);

  int getActualLine(int visualLine) {
    int currentLine = 0;
    int currentVisualLine = 0;

    while (currentVisualLine < visualLine && currentLine < _lines.length) {
      if (isLineFolded(currentLine)) {
        currentLine = getFoldedRange(currentLine) + 1;
      } else {
        currentLine++;
      }
      currentVisualLine++;
    }

    return currentLine;
  }

  int getFoldedRange(int line) {
    return _foldedRanges[line] ?? line;
  }

  (int, int) getBufferPosition(int visualLine) {
    int currentVisualLine = 0;
    int currentBufferLine = 0;

    while (
        currentVisualLine < visualLine && currentBufferLine < _lines.length) {
      if (isLineFolded(currentBufferLine)) {
        currentBufferLine +=
            _foldedRanges[currentBufferLine]! - currentBufferLine + 1;
      } else {
        currentBufferLine++;
      }
      currentVisualLine++;
    }

    return (currentBufferLine, 0);
  }

  void foldLines(int startLine, int endLine) {
    if (startLine >= endLine || startLine < 0 || endLine >= _lines.length) {
      return;
    }

    _foldedRanges[startLine] = endLine;
    incrementVersion();
  }

  void unfoldLines(int line) {
    if (!isLineFolded(line)) return;

    _foldedRanges.remove(line);
    incrementVersion();
  }

  void insertLine(int lineNumber, {String content = ''}) {
    _lines.insert(lineNumber, content);

    // Update folding ranges after the insertion point
    for (var entry in _foldedRanges.entries) {
      if (lineNumber <= entry.key) {
        _foldedRanges[entry.key + 1] = _foldedRanges.remove(entry.key)! + 1;
      } else if (lineNumber <= entry.value) {
        _foldedRanges[entry.key] = entry.value + 1;
      }
    }

    incrementVersion();
  }

  void removeLine(int lineNumber) {
    // Add bounds checking
    if (lineNumber < 0 || lineNumber >= _lines.length) {
      return; // Early return if line number is out of bounds
    }

    _lines.removeAt(lineNumber);

    // Update folding ranges after the removal point
    var rangesToUpdate = Map<int, int>.from(
        _foldedRanges); // Create a copy to avoid modification during iteration
    for (var entry in rangesToUpdate.entries) {
      if (lineNumber < entry.key) {
        // Fold start is after removed line
        _foldedRanges[entry.key - 1] = _foldedRanges.remove(entry.key)! - 1;
      } else if (lineNumber <= entry.value) {
        // Removed line is within fold range
        if (lineNumber == entry.key) {
          // Remove fold if start line is removed
          _foldedRanges.remove(entry.key);
        } else {
          // Adjust end of fold range
          _foldedRanges[entry.key] = entry.value - 1;
        }
      }
    }

    incrementVersion();
  }

  String getLine(int index) {
    // Add bounds checking
    if (index < 0 || index >= lines.length) {
      return '';
    }
    return lines[index];
  }

  int getLineLength(int lineNumber) => _lines[lineNumber].length;

  void incrementVersion() => _version++;

  void setContent(String content) {
    // Split content into lines and update the editor state
    _lines = content.split('\n');
    if (lines.isEmpty) {
      _lines = [''];
    }

    // Process content the same way as the content getter
    StringBuffer buffer = StringBuffer();
    for (int i = 0; i < _lines.length; i++) {
      buffer.writeln(_lines[i]);
    }

    incrementVersion();
    _originalContent = buffer.toString().trimRight();
  }

  void replace(int lineNumber, int index, int length, String newTerm) {
    _lines[lineNumber] = _lines[lineNumber].substring(0, index) +
        newTerm +
        _lines[lineNumber].substring(index + length);
    incrementVersion();
  }

  void setLine(int lineNumber, String content) {
    _lines[lineNumber] = content;
    incrementVersion();
  }

  void setOriginalContent(String content) {
    // Process the content the same way as the content getter
    StringBuffer buffer = StringBuffer();
    List<String> lines = content.split('\n');

    for (int i = 0; i < lines.length; i++) {
      buffer.writeln(lines[i]);
    }

    _originalContent = buffer.toString().trimRight();
    incrementVersion();
  }
}
