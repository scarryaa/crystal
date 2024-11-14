import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/folding_state.dart';
import 'package:crystal/models/selection.dart';
import 'package:flutter/material.dart';

class FoldingManager extends ChangeNotifier {
  final FoldingState foldingState = FoldingState();
  final Buffer buffer;
  final closingSymbols = ['}', ')', ']', '>'];

  FoldingManager(this.buffer);

  bool isFolded(int line) => foldingState.isLineFolded(line);

  Map<int, int> get foldedRegions => foldingState.foldingRanges;

  void toggleFold(int startLine, int endLine) {
    if (isFolded(startLine)) {
      unfold(startLine);
    } else {
      fold(startLine, endLine);
    }
    notifyListeners();
  }

  void fold(int startLine, int endLine) {
    // Unfold any existing folds within this region
    final existingFolds = _getExistingFoldsInRange(startLine, endLine);
    for (final foldStart in existingFolds) {
      unfold(foldStart);
    }

    buffer.foldLines(startLine, endLine);
    foldingState.fold(startLine, endLine);
    notifyListeners();
  }

  void unfold(int startLine) {
    if (!isFolded(startLine)) return;

    // Unfold any nested folds within this region
    final endLine = foldingState.foldingRanges[startLine]!;
    final nestedFolds = _getNestedFolds(startLine, endLine);
    for (final nestedStart in nestedFolds) {
      unfold(nestedStart);
    }

    buffer.unfoldLines(startLine);
    foldingState.unfold(startLine);
    notifyListeners();
  }

  List<int> _getNestedFolds(int startLine, int endLine) {
    return foldingState.foldingRanges.keys
        .where((line) => line > startLine && line <= endLine)
        .toList();
  }

  List<int> _getExistingFoldsInRange(int startLine, int endLine) {
    return foldingState.foldingRanges.keys
        .where((line) => line >= startLine && line <= endLine)
        .toList();
  }

  List<int> getVisibleLines() {
    return foldingState.getVisibleLines(buffer.lines);
  }

  bool isLineHidden(int line) {
    return foldingState.isLineHidden(line);
  }

  int? getFoldableRegionEnd(int line, List<String> lines) {
    if (line >= lines.length) return null;

    const openingBracket = '{';
    const closingBracket = '}';
    int bracketCount = 0;
    bool foundOpeningBracket = false;

    // Check if the current line contains an opening bracket
    if (!lines[line].contains(openingBracket)) return null;

    // Find the position of the first opening bracket on the current line
    int openingPosition = lines[line].indexOf(openingBracket);

    for (int i = line; i < lines.length; i++) {
      final currentLine = lines[i];

      for (int j = i == line ? openingPosition : 0;
          j < currentLine.length;
          j++) {
        if (currentLine[j] == openingBracket) {
          bracketCount++;
          foundOpeningBracket = true;
        } else if (currentLine[j] == closingBracket) {
          bracketCount--;
        }

        if (foundOpeningBracket && bracketCount == 0) {
          // Only return if the closing bracket is not on the same line as the opening bracket
          return i > line ? i : null;
        }
      }
    }

    return null; // No matching closing bracket found
  }

  void unfoldAtCursor(Cursor cursor) {
    if (cursor.column > 0) {
      final lineContent = buffer.getLine(cursor.line);
      final charBeforeCursor = lineContent[cursor.column - 1];

      if ('{([<'.contains(charBeforeCursor) &&
          buffer.foldedRanges.containsKey(cursor.line)) {
        final foldEnd = buffer.foldedRanges[cursor.line]!;
        buffer.unfoldLines(cursor.line);
        foldingState.toggleFold(cursor.line, foldEnd);
      }
    }
  }

  void unfoldBeforeCursor(Cursor cursor) {
    if (cursor.column == 0 && cursor.line > 0) {
      for (var entry in buffer.foldedRanges.entries) {
        final foldStart = entry.key;
        final foldEnd = entry.value;

        if (cursor.line - 1 >= foldStart && cursor.line - 1 <= foldEnd) {
          buffer.unfoldLines(foldStart);
          foldingState.toggleFold(foldStart, foldEnd + 1);
          break;
        }
      }
    }
  }

  int getNextVisibleLine(int currentLine) {
    int nextLine = currentLine + 1;
    while (nextLine < buffer.lineCount && foldingState.isLineHidden(nextLine)) {
      nextLine++;
    }
    return nextLine < buffer.lineCount ? nextLine : currentLine;
  }

  int getPreviousVisibleLine(int currentLine) {
    int prevLine = currentLine - 1;
    while (prevLine >= 0 && foldingState.isLineHidden(prevLine)) {
      prevLine--;
    }
    return prevLine >= 0 ? prevLine : currentLine;
  }

  MapEntry<int, int>? getFoldedRegionForLine(int lineNumber) {
    for (var entry in foldedRegions.entries) {
      if (lineNumber >= entry.key && lineNumber <= entry.value) {
        return entry;
      }
    }
    return null;
  }

  void unfoldAtClosingSymbol(Cursor cursor) {
    for (var entry in buffer.foldedRanges.entries) {
      final foldStart = entry.key;
      final foldEnd = entry.value + 1;
      final lineContent = buffer.getLine(foldEnd);
      if (isCursorAtClosingSymbol(cursor, lineContent, foldEnd, true)) {
        buffer.unfoldLines(foldStart);
        foldingState.toggleFold(foldStart, foldEnd);
        break;
      }
    }
  }

  bool selectionContainsFoldEnd(Selection selection, int foldEndLine) {
    final adjustedEndLine = foldEndLine + 1;
    final endLineContent = buffer.getLine(adjustedEndLine);

    // Find the last closing symbol in the line
    String? closingSymbol;
    int symbolIndex = -1;

    for (final symbol in closingSymbols) {
      final lastIndex = endLineContent.lastIndexOf(symbol);
      if (lastIndex > symbolIndex) {
        symbolIndex = lastIndex;
        closingSymbol = symbol;
      }
    }

    if (closingSymbol == null || symbolIndex == -1) return false;

    // Check if the selection contains the closing symbol
    if (selection.startLine == adjustedEndLine &&
        selection.endLine == adjustedEndLine) {
      // Single line selection
      final selStart = min(selection.startColumn, selection.endColumn);
      final selEnd = max(selection.startColumn, selection.endColumn);
      return symbolIndex >= selStart && symbolIndex <= selEnd;
    } else if (selection.startLine <= adjustedEndLine &&
        selection.endLine >= adjustedEndLine) {
      // Multi-line selection
      if (selection.startLine == adjustedEndLine) {
        // Check if selection start is before or at symbol
        return selection.startColumn <= symbolIndex;
      } else if (selection.endLine == adjustedEndLine) {
        // Check if selection end is after or at symbol
        return selection.endColumn >= symbolIndex;
      }
      return true; // Whole line is selected
    }

    return false;
  }

  bool isCursorAtClosingSymbol(
      Cursor cursor, String lineContent, int lineNumber, bool isBackspace) {
    for (final symbol in closingSymbols) {
      final symbolIndex = lineContent.lastIndexOf(symbol);
      if (symbolIndex == -1) continue;

      if (isBackspace) {
        // For backspace, check if cursor is:
        // 1. Right after the symbol
        // 2. At the symbol
        // 3. Just before the symbol (for line endings)
        if (cursor.line == lineNumber &&
            (cursor.column == symbolIndex + 1 ||
                cursor.column == symbolIndex ||
                cursor.column == symbolIndex - 1)) {
          return true;
        }
      } else {
        // For delete, check if cursor is:
        // 1. Just before the symbol
        // 2. At the symbol
        if (cursor.line == lineNumber &&
            (cursor.column == symbolIndex ||
                cursor.column == symbolIndex - 1)) {
          return true;
        }
      }
    }
    return false;
  }

  void updateFoldedRegionsAfterEdit(Set<int> affectedLines) {
    final regionsToCheck = <int, int>{};

    // Check the affected lines and their surrounding regions
    for (final line in affectedLines) {
      if (foldingState.isLineFolded(line)) {
        regionsToCheck[line] = foldingState.foldingRanges[line]!;
      }
      // Check if the line is within any folded region
      for (final entry in foldingState.foldingRanges.entries) {
        if (line > entry.key && line <= entry.value) {
          regionsToCheck[entry.key] = entry.value;
        }
      }
    }

    // Re-evaluate each affected folded region
    for (final entry in regionsToCheck.entries) {
      final startLine = entry.key;
      final originalEndLine = entry.value;

      final newEndLine = getFoldableRegionEnd(startLine, buffer.lines);
      if (newEndLine == null || newEndLine != originalEndLine) {
        // Region is no longer valid, unfold it
        unfold(startLine);
      } else {
        // Update the folded region if needed
        foldingState.unfold(startLine);
        foldingState.fold(startLine, newEndLine);
      }
    }

    notifyListeners();
  }
}
