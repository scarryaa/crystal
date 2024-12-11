import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/selection/selection_direction.dart';

class Selection {
  int anchor;
  int startIndex;
  int endIndex;
  int startLine;
  int endLine;

  Selection({
    this.anchor = -1,
    this.startIndex = -1,
    this.endIndex = -1,
    this.startLine = -1,
    this.endLine = -1,
  });

  void start(int line, int index) {
    startLine = endLine = line;
    startIndex = endIndex = anchor = index;
  }

  void reset() {
    startLine = endLine = anchor = startIndex = endIndex = -1;
  }

  bool isNullSelection() {
    return anchor == -1 &&
        startIndex == -1 &&
        endIndex == -1 &&
        startLine == -1 &&
        endLine == -1;
  }

  void selectRange(BufferManager bufferManager, int startLine, int startIndex,
      int endLine, int endIndex) {
    this.startLine = max(0, startLine);
    this.endLine = max(0, min(bufferManager.lines.length - 1, endLine));

    this.startIndex =
        max(0, min(bufferManager.lines[this.startLine].length, startIndex));
    this.endIndex =
        max(0, min(bufferManager.lines[this.endLine].length, endIndex));

    anchor = this.startIndex;
  }

  void normalize(BufferManager bufferManager) {
    final int temp2 = startIndex;

    if (startLine > endLine) {
      final int temp = startLine;
      startLine = endLine;
      endLine = temp;

      startIndex = endIndex;
      endIndex = temp2;
    }

    if (startLine == endLine && startIndex > endIndex) {
      startIndex = endIndex;
      endIndex = temp2;
    }
  }

  int selectWord(BufferManager bufferManager, int cursorLine, int cursorIndex) {
    final String lineContent = bufferManager.lines[cursorLine];

    if (cursorIndex < 0 || cursorIndex >= lineContent.length) {
      return cursorIndex;
    }

    int start = cursorIndex;
    int end = cursorIndex;

    // Move start backwards to find the beginning of the word
    while (start > 0 && isWordCharacter(lineContent[start - 1])) {
      start--;
    }

    // Move end forwards to find the end of the word
    while (end < lineContent.length && isWordCharacter(lineContent[end])) {
      end++;
    }

    anchor = end;
    startIndex = start;
    endIndex = end;
    startLine = endLine = cursorLine;

    return end;
  }

  bool isWordCharacter(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  void selectLine(BufferManager bufferManager, int cursorLine) {
    anchor = startIndex = 0;
    startLine = endLine = cursorLine;
    endIndex = bufferManager.lines[startLine].length;
    endLine++;

    if (endLine > bufferManager.lines.length - 1) {
      endLine = min(endLine, bufferManager.lines.length - 1);
    } else {
      endIndex = 0;
    }
  }

  void updateSelection(BufferManager bufferManager,
      SelectionDirection direction, int currentIndex, int targetIndex) {
    switch (direction) {
      case SelectionDirection.backward:
        print(startIndex);
        if (startIndex == 0 && startLine > 0) {
          startLine--;
          startIndex = bufferManager.lines[startLine].length;
          targetIndex = startIndex;
        } else if (startIndex > 0) {
          startIndex--;
          targetIndex = startIndex;
        }
        break;

      case SelectionDirection.forward:
        // If currentIndex equals startIndex, it is a backwards selection
        // so try to shrink the selection
        if (currentIndex == startIndex) {
          if (startIndex == bufferManager.lines[startLine].length &&
              startLine + 1 < bufferManager.lines.length) {
            // We're at the end of the line
            startLine++;
            startIndex = 0;
            targetIndex = startIndex;
          } else if (startIndex < bufferManager.lines[startLine].length) {
            startIndex++;
            targetIndex = startIndex;
          }
        } else {
          if (endIndex == bufferManager.lines[endLine].length &&
              endLine + 1 < bufferManager.lines.length) {
            endLine++;
            endIndex = 0;
            targetIndex = endIndex;
          } else if (endIndex < bufferManager.lines[endLine].length) {
            endIndex++;
            targetIndex = endIndex;
          }
        }
        break;

      case SelectionDirection.previousLine:
        if (startLine > 0) {
          startLine--;
          startIndex = min(targetIndex, bufferManager.lines[startLine].length);
        } else if (startLine == 0) {
          startIndex = 0;
          targetIndex = startIndex;
        }
        break;

      case SelectionDirection.nextLine:
        // If currentIndex equals startIndex, it is a backwards selection
        // so try to shrink the selection
        if (currentIndex == startIndex) {
          if (startLine < bufferManager.lines.length - 1) {
            startLine++;
            startIndex =
                min(targetIndex, bufferManager.lines[startLine].length);
          } else {
            startIndex = bufferManager.lines[startLine].length;
            targetIndex = startIndex;
          }
        } else {
          if (endLine < bufferManager.lines.length - 1) {
            endLine++;
            endIndex = min(targetIndex, bufferManager.lines[endLine].length);
          } else if (endLine == bufferManager.lines.length - 1) {
            endIndex = bufferManager.lines[endLine].length;
            targetIndex = endIndex;
          }
        }
        break;
    }
  }

  bool hasSelection() {
    return !(startLine == -1 &&
            endLine == -1 &&
            anchor == -1 &&
            startIndex == -1 &&
            endIndex == -1) &&
        (startLine != endLine || startIndex != endIndex);
  }

  String getSelectedText(BufferManager bufferManager) {
    if (startLine == endLine) {
      return bufferManager.lines[startLine].substring(startIndex, endIndex);
    }

    final List<String> selectedLines = [
      bufferManager.lines[startLine].substring(startIndex),
      ...bufferManager.lines.sublist(startLine + 1, endLine),
      bufferManager.lines[endLine].substring(0, endIndex)
    ];

    return selectedLines.join('\n');
  }

  (int, int) deleteSelection(BufferManager bufferManager, int currentIndex) {
    // First determine which indices to use based on line numbers
    final int normalizedStartLine = min(startLine, endLine);
    final int normalizedEndLine = max(startLine, endLine);

    if (normalizedStartLine == normalizedEndLine) {
      final int normalizedStartIndex = min(startIndex, endIndex);
      final int normalizedEndIndex = max(startIndex, endIndex);
      print(normalizedEndIndex - normalizedStartIndex);

      bufferManager.deleteRange(normalizedStartLine, normalizedEndLine,
          normalizedStartIndex, normalizedEndIndex);
      return (0, normalizedEndIndex - normalizedStartIndex);
    } else {
      final int normalizedStartIndex =
          (normalizedStartLine == startLine) ? startIndex : endIndex;
      final int normalizedEndIndex =
          (normalizedEndLine == endLine) ? endIndex : startIndex;
      print(normalizedEndIndex - normalizedStartIndex);

      bufferManager.deleteRange(normalizedStartLine, normalizedEndLine,
          normalizedStartIndex, normalizedEndIndex);
      return (
        normalizedEndLine - normalizedStartLine,
        normalizedEndIndex - normalizedStartIndex
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Selection &&
          anchor == other.anchor &&
          startLine == other.startLine &&
          endLine == other.endLine &&
          startIndex == other.startIndex &&
          endIndex == other.endIndex;

  @override
  int get hashCode =>
      Object.hash(anchor, startLine, endLine, startIndex, endIndex);
}
