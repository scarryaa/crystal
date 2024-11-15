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

  // Add support for different folding strategies
  final bool useIndentationFolding;

  FoldingManager(this.buffer, {this.useIndentationFolding = false});

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

  // Get the indentation level of a line
  int _getIndentationLevel(String line) {
    final match = RegExp(r'^\s*').firstMatch(line);
    if (match == null) return 0;

    final indent = match.group(0) ?? '';
    // For tab indentation
    if (indent.contains('\t')) {
      return indent.length;
    }
    // For space indentation (assuming 2 or 4 spaces)
    return (indent.length / 2)
        .floor(); // Adjust divisor based on your space count
  }

  // Find the end of an indentation-based block
  int? _getIndentationBlockEnd(int startLine, List<String> lines) {
    if (startLine >= lines.length) return null;

    final startIndentation = _getIndentationLevel(lines[startLine]);

    // Skip empty starting lines
    if (lines[startLine].trim().isEmpty) return null;

    for (int i = startLine + 1; i < lines.length; i++) {
      final currentLine = lines[i].trimRight();

      // Skip empty lines
      if (currentLine.isEmpty) continue;

      final currentIndentation = _getIndentationLevel(lines[i]);

      // If we find a line with same or less indentation,
      // the block ends at the previous line
      if (currentIndentation <= startIndentation) {
        return i - 1;
      }
    }

    // If we reach the end, the block ends at the last line
    return lines.length - 1;
  }

  int? getFoldableRegionEnd(int line, List<String> lines) {
    if (line >= lines.length) return null;

    // If using indentation-based folding
    if (useIndentationFolding) {
      return _getIndentationBlockEnd(line, lines);
    }

    // Original bracket-based folding logic
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
          return i > line ? i : null;
        }
      }
    }

    return null;
  }

  // Check if a line can be folded
  bool canFold(int line) {
    if (line >= buffer.lines.length) return false;

    if (useIndentationFolding) {
      // For indentation-based folding, check if there's a nested block
      final currentLine = buffer.getLine(line).trimRight();
      if (currentLine.isEmpty) return false;

      final currentIndentation = _getIndentationLevel(currentLine);

      // Check if next non-empty line has greater indentation
      for (int i = line + 1; i < buffer.lines.length; i++) {
        final nextLine = buffer.getLine(i).trimRight();
        if (nextLine.isEmpty) continue;

        return _getIndentationLevel(nextLine) > currentIndentation;
      }
      return false;
    } else {
      // For bracket-based folding, check if there's a valid folding region
      return getFoldableRegionEnd(line, buffer.lines) != null;
    }
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

  bool isLineFolded(int line) {
    return foldingState.isLineFolded(line);
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
