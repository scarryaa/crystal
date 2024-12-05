import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/selection/selection_direction.dart';

class SelectionManager {
  int anchor = -1;
  int startIndex = -1;
  int endIndex = -1;
  int startLine = -1;
  int endLine = -1;

  void startSelection(int line, int index) {
    startLine = line;
    endLine = line;
    startIndex = index;
    endIndex = index;
    anchor = index;
  }

  void deleteSelection(BufferManager bufferManager, int currentIndex) {
    // First determine which indices to use based on line numbers
    int normalizedStartLine = min(startLine, endLine);
    int normalizedEndLine = max(startLine, endLine);

    if (normalizedStartLine == normalizedEndLine) {
      int normalizedStartIndex = min(startIndex, endIndex);
      int normalizedEndIndex = max(startIndex, endIndex);
      bufferManager.deleteRange(normalizedStartLine, normalizedEndLine,
          normalizedStartIndex, normalizedEndIndex);
    } else {
      int normalizedStartIndex =
          (normalizedStartLine == startLine) ? startIndex : endIndex;
      int normalizedEndIndex =
          (normalizedEndLine == endLine) ? endIndex : startIndex;
      bufferManager.deleteRange(normalizedStartLine, normalizedEndLine,
          normalizedStartIndex, normalizedEndIndex);
    }
  }

  void selectAll(BufferManager bufferManager) {
    if (bufferManager.lines.isEmpty) {
      startLine = endLine = 0;
      startIndex = endIndex = anchor = 0;
      return;
    }
    anchor = startIndex = startLine = 0;
    endLine = bufferManager.lines.length - 1;
    endIndex = bufferManager.lines[endLine].length;
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

  int selectWord(BufferManager bufferManager, int cursorLine, int cursorIndex) {
    String lineContent = bufferManager.lines[cursorLine];

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
    endIndex = 0;
  }

  void updateSelection(BufferManager bufferManager,
      SelectionDirection direction, int currentIndex, int targetIndex) {
    switch (direction) {
      case SelectionDirection.backward:
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

  void resetSelection() {
    startLine = endLine = anchor = startIndex = endIndex = -1;
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
    // Single line selection
    if (startLine == endLine) {
      return bufferManager.lines[startLine].substring(startIndex, endIndex);
    }

    // Multiline selection
    final List<String> selectedLines = [
      // First line
      bufferManager.lines[startLine].substring(startIndex),

      // Middle lines
      ...bufferManager.lines.sublist(startLine + 1, endLine),

      // Last line
      bufferManager.lines[endLine].substring(0, endIndex)
    ];

    return selectedLines.join('\n');
  }
}
