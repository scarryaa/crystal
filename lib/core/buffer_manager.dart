import 'package:crystal/core/cursor_manager.dart';

class BufferManager {
  final List<String> _lines = [''];
  late final CursorManager cursorManager;

  List<String> get lines => List<String>.from(_lines);

  void insertString(String string) {
    List<String> linesToAdd = string.split('\n');
    int numberOfLinesAdded = linesToAdd.length - 1;

    if (numberOfLinesAdded == 0) {
      _lines[cursorManager.cursorLine] += linesToAdd.first;
      cursorManager.cursorIndex += linesToAdd.first.length;
      cursorManager.targetCursorIndex = cursorManager.cursorIndex;
    } else {
      _lines.removeAt(cursorManager.cursorLine);
      _lines.insertAll(cursorManager.cursorLine, linesToAdd);
      cursorManager.cursorLine += numberOfLinesAdded;
      cursorManager.cursorIndex = linesToAdd.last.length;
      cursorManager.targetCursorIndex = cursorManager.cursorIndex;
    }
  }

  void insertCharacter(String char) {
    _lines[cursorManager.cursorLine] = _lines[cursorManager.cursorLine]
            .substring(0, cursorManager.cursorIndex) +
        char +
        _lines[cursorManager.cursorLine].substring(cursorManager.cursorIndex);
    cursorManager.cursorIndex++;
    cursorManager.targetCursorIndex = cursorManager.cursorIndex;
  }

  void insertNewline() {
    _lines.insert(cursorManager.cursorLine + 1, '');
    cursorManager.cursorLine++;
    cursorManager.cursorIndex = 0;
    cursorManager.targetCursorIndex = cursorManager.cursorIndex;
  }

  void deleteRange(int startLine, int endLine, int startIndex, int endIndex) {
    if (startLine < 0 ||
        endLine >= _lines.length ||
        startLine > endLine ||
        startIndex < 0 ||
        endIndex > _lines[endLine].length) {
      throw ArgumentError('Invalid range parameters');
    }

    // Single line deletion
    if (startLine == endLine) {
      String currentLine = _lines[startLine];
      _lines[startLine] = currentLine.substring(0, startIndex) +
          currentLine.substring(endIndex);

      cursorManager.cursorLine = startLine;
      cursorManager.cursorIndex = startIndex;
      return;
    }

    // Multi-line deletion
    // Keep the text before startIndex in the first line
    String firstLinePart = _lines[startLine].substring(0, startIndex);

    // Keep the text after endIndex in the last line
    String lastLinePart = _lines[endLine].substring(endIndex);

    // Remove intermediate lines
    _lines.removeRange(startLine + 1, endLine + 1);

    // Combine first and last line parts
    _lines[startLine] = firstLinePart + lastLinePart;

    cursorManager.cursorLine = startLine;
    cursorManager.cursorIndex = startIndex;
  }

  void delete(int length) {
    if (!_validateCursorPositionBeforeDelete()) return;

    if (cursorManager.cursorIndex == 0 && cursorManager.cursorLine > 0) {
      // When cursor is at the start of a line (except first line)
      String currentLineContent = _lines[cursorManager.cursorLine];
      // Remove the current line
      _lines.removeAt(cursorManager.cursorLine);
      // Move cursor to end of previous line
      cursorManager.cursorLine--;
      cursorManager.cursorIndex = _lines[cursorManager.cursorLine].length;
      // Append current line content to previous line
      _lines[cursorManager.cursorLine] += currentLineContent;
    } else if (cursorManager.cursorIndex > 0) {
      // When cursor is in the middle or end of a line
      _lines[cursorManager.cursorLine] = _lines[cursorManager.cursorLine]
              .substring(0, cursorManager.cursorIndex - length) +
          _lines[cursorManager.cursorLine].substring(cursorManager.cursorIndex);
      cursorManager.cursorIndex -= length;
    }

    cursorManager.targetCursorIndex = cursorManager.cursorIndex;
  }

  void deleteForwards(int length) {
    if (length <= 0) return;

    // Check if we're at the end of the document
    if (cursorManager.cursorLine == _lines.length - 1 &&
        cursorManager.cursorIndex >= _lines[cursorManager.cursorLine].length) {
      return;
    }

    // Deletion within the same line
    int currentLineLength = _lines[cursorManager.cursorLine].length;
    int remainingInLine = currentLineLength - cursorManager.cursorIndex;

    if (length <= remainingInLine) {
      _lines[cursorManager.cursorLine] = _lines[cursorManager.cursorLine]
              .substring(0, cursorManager.cursorIndex) +
          _lines[cursorManager.cursorLine]
              .substring(cursorManager.cursorIndex + length);
      return;
    }

    // Multi-line deletion
    int remainingCharsToDelete = length;
    int currentLine = cursorManager.cursorLine;

    while (remainingCharsToDelete > 0 && currentLine < _lines.length - 1) {
      String currentLineContent = _lines[currentLine];
      int currentLineRemainingChars =
          currentLineContent.length - cursorManager.cursorIndex;

      if (remainingCharsToDelete <= currentLineRemainingChars) {
        // Partial line deletion
        _lines[currentLine] = currentLineContent.substring(
                0, cursorManager.cursorIndex) +
            currentLineContent
                .substring(cursorManager.cursorIndex + remainingCharsToDelete);
        break;
      }

      // Remove this line or part of it
      remainingCharsToDelete -= currentLineRemainingChars + 1; // +1 for newline
      _lines.removeAt(currentLine);
    }
  }

  bool _validateCursorPositionBeforeDelete() {
    if (cursorManager.cursorIndex - 1 < 0 && cursorManager.cursorLine == 0) {
      return false;
    }
    return true;
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
