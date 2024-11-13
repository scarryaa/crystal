class Buffer {
  int _version = 1;
  List<String> _lines = [''];
  String _originalContent = '';
  final Map<int, List<String>> _foldedContent = {};
  final Map<int, int> _foldedRanges = {};

  int get version => _version;
  bool get isDirty => _originalContent != content;
  List<String> get lines => _lines;
  int get lineCount => _lines.length;
  bool get isEmpty => _lines.isEmpty;

  String get content {
    StringBuffer buffer = StringBuffer();
    int currentLine = 0;

    while (currentLine < _lines.length) {
      buffer.writeln(_lines[currentLine]);

      if (isLineFolded(currentLine)) {
        // Add folded content
        for (var line in _foldedContent[currentLine]!) {
          buffer.writeln(line);
        }
      }
      currentLine++;
    }

    return buffer.toString().trimRight();
  }

  Map<int, int> get foldedRanges => _foldedRanges;

  bool isLineFolded(int line) => _foldedRanges.containsKey(line);

  List<String> getFoldedContent(int line) => _foldedContent[line] ?? [];

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

    // Store folded content
    _foldedContent[startLine] = _lines.sublist(startLine + 1, endLine + 1);
    _foldedRanges[startLine] = endLine;

    // Remove folded lines from main buffer
    _lines.removeRange(startLine + 1, endLine + 1);

    incrementVersion();
  }

  void unfoldLines(int line) {
    if (!isLineFolded(line)) return;

    final foldedContent = _foldedContent[line]!;
    final insertPosition = line + 1;

    // Reinsert folded content
    _lines.insertAll(insertPosition, foldedContent);

    // Clear folding data
    _foldedContent.remove(line);
    _foldedRanges.remove(line);

    incrementVersion();
  }

  void insertLine(int lineNumber, {String content = ''}) {
    // Check if inserting into folded region
    for (var entry in _foldedRanges.entries) {
      if (lineNumber > entry.key && lineNumber <= entry.value) {
        _foldedContent[entry.key]!.insert(lineNumber - entry.key - 1, content);
        _foldedRanges[entry.key] = _foldedRanges[entry.key]! + 1;
        incrementVersion();
        return;
      }
    }

    _lines.insert(lineNumber, content);
    incrementVersion();
  }

  void removeLine(int lineNumber) {
    // Check if removing from folded region
    for (var entry in _foldedRanges.entries) {
      if (lineNumber > entry.key && lineNumber <= entry.value) {
        _foldedContent[entry.key]!.removeAt(lineNumber - entry.key - 1);
        _foldedRanges[entry.key] = _foldedRanges[entry.key]! - 1;
        incrementVersion();
        return;
      }
    }

    _lines.removeAt(lineNumber);
    incrementVersion();
  }

  String getLine(int lineNumber) {
    // Check if line is in folded region
    for (var entry in _foldedRanges.entries) {
      if (lineNumber > entry.key && lineNumber <= entry.value) {
        return _foldedContent[entry.key]![lineNumber - entry.key - 1];
      }
    }
    return _lines[lineNumber];
  }

  int getLineLength(int lineNumber) => _lines[lineNumber].length;

  void incrementVersion() => _version++;

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
    // Check if replacing in folded region
    for (var entry in _foldedRanges.entries) {
      if (lineNumber > entry.key && lineNumber <= entry.value) {
        final foldedLine =
            _foldedContent[entry.key]![lineNumber - entry.key - 1];
        _foldedContent[entry.key]![lineNumber - entry.key - 1] =
            foldedLine.substring(0, index) +
                newTerm +
                foldedLine.substring(index + length);
        return;
      }
    }

    _lines[lineNumber] = _lines[lineNumber].substring(0, index) +
        newTerm +
        _lines[lineNumber].substring(index + length);
  }

  void setOriginalContent(String content) {
    _originalContent = content;
  }

  void setLine(int lineNumber, String content) {
    // Check if line is in folded region
    for (var entry in _foldedRanges.entries) {
      if (lineNumber > entry.key && lineNumber <= entry.value) {
        _foldedContent[entry.key]![lineNumber - entry.key - 1] = content;
        return;
      }
    }
    _lines[lineNumber] = content;
  }
}
