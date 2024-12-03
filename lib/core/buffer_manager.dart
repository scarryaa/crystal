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
    // Check if there is actually content after the cursor
    if (_lines[cursorManager.cursorLine].length > cursorManager.cursorIndex) {
      // Deleting before the end of the line
      if (cursorManager.cursorIndex < _lines[cursorManager.cursorLine].length) {
        _lines[cursorManager.cursorLine] = _lines[cursorManager.cursorLine]
            .substring(0, _lines[cursorManager.cursorLine].length - length);
        // Deleting at the end of the line
      } else {
        _lines[cursorManager.cursorLine + 1] =
            _lines[cursorManager.cursorLine + 1].substring(
                0, _lines[cursorManager.cursorLine + 1].length - length);
      }
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
