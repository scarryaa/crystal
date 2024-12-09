import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';

class BufferManager {
  List<String> _lines;
  late final CursorManager cursorManager;

  BufferManager({List<String>? initialLines, CursorManager? cursorManager})
      : _lines = initialLines ?? [''] {
    cursorManager = cursorManager ?? CursorManager(this);
  }

  String getLineAt(int index) => _lines[index];
  set lines(List<String> lines) => lines = lines;
  int get lineCount => _lines.length;
  String get currentLine => _lines[cursorManager.firstCursor().line];
  List<String> get lines => List<String>.from(_lines);

  void insertString(String string) {
    final List<String> linesToAdd = string.split('\n');
    final int numberOfLinesAdded = linesToAdd.length - 1;

    for (var cursor in cursorManager.cursors) {
      if (numberOfLinesAdded == 0) {
        _lines[cursor.line] += linesToAdd.first;
        cursor.index += linesToAdd.first.length;
        cursorManager.targetCursorIndex = cursor.index;
      } else {
        _lines.removeAt(cursor.line);
        _lines.insertAll(cursor.line, linesToAdd);
        cursor.line += numberOfLinesAdded;
        cursor.index = linesToAdd.last.length;
        cursorManager.targetCursorIndex = cursor.index;
      }
    }
  }

  void setText(String text) {
    _lines = text.split('\n');
  }

  void insertCharacter(String char) {
    cursorManager.sortCursors();

    // Track cumulative offset per line
    final Map<int, int> lineOffsets = {};
    for (var cursor in cursorManager.cursors) {
      final currentOffset = lineOffsets[cursor.line] ?? 0;

      _lines[cursor.line] =
          _lines[cursor.line].substring(0, cursor.index + currentOffset) +
              char +
              _lines[cursor.line].substring(cursor.index + currentOffset);

      cursor.index++;
      cursor.index += currentOffset;

      lineOffsets.update(
        cursor.line,
        (value) => value + 1,
        ifAbsent: () => 1,
      );

      cursorManager.targetCursorIndex = cursor.index;
    }
    cursorManager.mergeCursorsIfNeeded();
  }

  void insertNewline() {
    for (var cursor in cursorManager.cursors) {
      final String rightPart = _lines[cursor.line].substring(cursor.index);
      _lines[cursor.line] = _lines[cursor.line].substring(0, cursor.index);
      _lines.insert(cursor.line + 1, '');
      _lines[cursor.line + 1] = rightPart;

      cursor.line++;
      cursor.index = 0;
      cursorManager.targetCursorIndex = cursor.index;
    }
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
      final String currentLine = _lines[startLine];
      _lines[startLine] = currentLine.substring(0, startIndex) +
          currentLine.substring(endIndex);

      cursorManager.firstCursor().line = startLine;
      cursorManager.firstCursor().index = startIndex;
      return;
    }

    // Multi-line deletion
    // Keep the text before startIndex in the first line
    final String firstLinePart = _lines[startLine].substring(0, startIndex);

    // Keep the text after endIndex in the last line
    final String lastLinePart = _lines[endLine].substring(endIndex);

    // Remove intermediate lines
    _lines.removeRange(startLine + 1, endLine + 1);

    // Combine first and last line parts
    _lines[startLine] = firstLinePart + lastLinePart;

    cursorManager.firstCursor().line = startLine;
    cursorManager.firstCursor().index = startIndex;
  }

  void delete(int length) {
    cursorManager.sortCursors();
    int deletedLines = 0;
    int sameLineAdjustment = 0;
    final Map<int, int> indexAdjustments = {};

    for (var cursor in cursorManager.cursors) {
      if (!_validateCursorPositionBeforeDelete(cursor)) return;

      if (cursor.index == 0 && cursor.line > 0) {
        // Cursor is at line start (not first line)
        final int indexAdjustment = indexAdjustments[cursor.line] ?? 0;
        cursor.line -= deletedLines;
        final String currentLineContent = _lines[cursor.line];
        final String previousLineContent = _lines[cursor.line - 1];
        _lines.removeAt(cursor.line);
        // Move cursor to end of previous line
        cursor.line--;
        cursor.index = _lines[cursor.line].length;
        cursor.index += indexAdjustment;
        indexAdjustments[cursor.line + 1] = previousLineContent.length;
        deletedLines++;

        // Append current line content to previous line
        _lines[cursor.line] += currentLineContent;
      } else if (cursor.index > 0) {
        // When cursor is in the middle or end of a line
        final int adjustment =
            -(indexAdjustments[cursor.line] ?? -sameLineAdjustment);
        cursor.line -= deletedLines;
        cursor.index -= adjustment;
        sameLineAdjustment += length;
        _lines[cursor.line] =
            _lines[cursor.line].substring(0, cursor.index - length) +
                _lines[cursor.line].substring(cursor.index);
        cursor.index -= length;
      }

      cursorManager.targetCursorIndex = cursor.index;
    }
    cursorManager.mergeCursorsIfNeeded();
  }

  void deleteForwards(int length) {
    for (var cursor in cursorManager.cursors) {
      if (length <= 0) return;
      // Check if we're at the end of the document
      if (cursor.line == _lines.length - 1 &&
          cursor.index >= _lines[cursor.line].length) {
        return;
      }
      // Deletion within the same line
      final int currentLineLength = _lines[cursor.line].length;
      final int remainingInLine = currentLineLength - cursor.index;
      if (length <= remainingInLine) {
        _lines[cursor.line] = _lines[cursor.line].substring(0, cursor.index) +
            _lines[cursor.line].substring(cursor.index + length);
        return;
      }
      // Multi-line deletion
      int remainingCharsToDelete = length;
      int currentLine = cursor.line;
      while (remainingCharsToDelete > 0 && currentLine < _lines.length - 1) {
        final String currentLineContent = _lines[currentLine];
        final int currentLineRemainingChars =
            currentLineContent.length - cursor.index;
        if (remainingCharsToDelete <= currentLineRemainingChars) {
          // Partial line deletion
          _lines[currentLine] = currentLineContent.substring(0, cursor.index) +
              currentLineContent
                  .substring(cursor.index + remainingCharsToDelete);
          break;
        }
        // Remove this line or part of it
        remainingCharsToDelete -=
            currentLineRemainingChars + 1; // +1 for newline

        if (currentLineRemainingChars == 0) {
          // We are at the end of a non-empty line
          // Combine current line with the next line
          if (currentLine + 1 < _lines.length) {
            _lines[currentLine] += _lines[currentLine + 1];
            _lines.removeAt(currentLine + 1);
          }
        } else {
          _lines[currentLine] = currentLineContent.substring(0, cursor.index);
        }

        currentLine++;
      }
    }
  }

  bool _validateCursorPositionBeforeDelete(Cursor cursor) {
    if (cursor.index - 1 < 0 && cursor.line == 0) {
      return false;
    }
    return true;
  }

  @override
  String toString() {
    return _lines.join('\n');
  }
}
