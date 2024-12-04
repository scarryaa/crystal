import 'package:crystal/core/cursor_manager.dart';

class BufferManager {
  final List<String> _lines = [''];
  late final CursorManager cursorManager;

  List<String> get lines => List<String>.from(_lines);

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
    int totalLength = 0;

    for (int i = startLine; i <= endLine; i++) {
      String line = lines[i];
      if (startLine == endLine) {
        // Single line deletion
        totalLength += endIndex - startIndex;
      } else if (i == startLine) {
        // First line: from startIndex to end
        totalLength += line.length - startIndex;
      } else if (i == endLine) {
        // Last line: from start to endIndex
        totalLength += endIndex;
      } else {
        // Middle lines: full length
        totalLength += line.length;
      }
    }

    cursorManager.cursorIndex = startIndex;
    cursorManager.cursorLine = startLine;
    deleteForwards(totalLength);
  }

  void delete(int length) {
    if (_validateCursorPositionBeforeDelete() == false) return;

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
    // Get remaining characters in current line after cursor
    int remainingInLine =
        _lines[cursorManager.cursorLine].length - cursorManager.cursorIndex;

    if (length > remainingInLine) {
      // Multi-line deletion
      int charsToDelete = length;
      int currentLine = cursorManager.cursorLine;

      // Keep track of first line's beginning
      String firstLinePart =
          _lines[currentLine].substring(0, cursorManager.cursorIndex);

      while (charsToDelete > 0 && currentLine < _lines.length) {
        // If we're still on first line, start from cursor
        int startIndex = (currentLine == cursorManager.cursorLine)
            ? cursorManager.cursorIndex
            : 0;

        int availableChars = _lines[currentLine].length - startIndex;

        if (charsToDelete > availableChars) {
          // Need to go to next line
          charsToDelete -= (availableChars);
          currentLine++;
        } else {
          // We can finish the deletion on this line
          String endPart =
              _lines[currentLine].substring(startIndex + charsToDelete);
          _lines[cursorManager.cursorLine] = firstLinePart + endPart;

          // Remove all lines in between
          if (currentLine > cursorManager.cursorLine) {
            _lines.removeRange(cursorManager.cursorLine + 1, currentLine + 1);
          }
          break;
        }
      }
    } else {
      // Single-line deletion
      _lines[cursorManager.cursorLine] = _lines[cursorManager.cursorLine]
              .substring(0, cursorManager.cursorIndex) +
          _lines[cursorManager.cursorLine]
              .substring(cursorManager.cursorIndex + length);
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
