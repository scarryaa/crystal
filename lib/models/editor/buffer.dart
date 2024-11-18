import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class Buffer extends ChangeNotifier {
  int _version = 1;
  List<String> _lines = [''];
  List<String> _originalLines = [''];
  final Map<int, int> _foldedRanges = {};
  bool _isDirty = false;

  bool get isDirty {
    if (_isDirty) return true;
    if (_lines.length != _originalLines.length) return true;
    for (int i = 0; i < _lines.length; i++) {
      if (_lines[i] != _originalLines[i]) return true;
    }
    return false;
  }

  void setContent(String content) {
    _lines = content.split('\n');
    if (_lines.isEmpty) {
      _lines = [''];
    }
    _originalLines = List.from(_lines);
    _isDirty = false;
    incrementVersion();
  }

  void incrementVersion() {
    _version++;
    notifyListeners();
  }

  void clearDirty() {
    _originalLines = List.from(_lines);
    _isDirty = false;
    notifyListeners();
  }

  void setOriginalContent(String content) {
    _originalLines = content.split('\n');
    if (_originalLines.isEmpty) {
      _originalLines = [''];
    }
    notifyListeners();
  }

  int get version => _version;

  set isDirty(bool value) {
    if (_isDirty != value) {
      _isDirty = value;
      notifyListeners();
    }
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
    if (lineNumber < 0 || lineNumber >= _lines.length) {
      throw RangeError('Invalid line number: $lineNumber');
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

  String getLine(int lineNumber) {
    if (lineNumber < 0 || lineNumber >= _lines.length) {
      throw RangeError('Invalid line number: $lineNumber');
    }
    return _lines[lineNumber];
  }

  int getLineLength(int lineNumber) => _lines[lineNumber].length;

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
}
