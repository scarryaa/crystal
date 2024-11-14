import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class IndentationPainter extends EditorPainterBase {
  final EditorState editorState;
  final double viewportHeight;

  IndentationPainter({
    required this.editorState,
    required this.viewportHeight,
    required super.editorLayoutService,
    required super.editorConfigService,
  });

  @override
  void paint(Canvas canvas, Size size,
      {required int firstVisibleLine, required int lastVisibleLine}) {
    final lines = editorState.buffer.lines;
    final cursors = editorState.editorCursorManager.cursors;
    Map<int, Set<int>> highlightedIndentRanges = {};
    Map<int, bool> isClosestIndentLevel = {};

    const bufferLines = 5;
    int visualLine = 0;
    int startLine = 0;

    // Find the first actual line to start painting
    while (startLine < lines.length &&
        visualLine < firstVisibleLine - bufferLines) {
      if (!editorState.isLineHidden(startLine)) {
        visualLine++;
      }
      startLine++;
    }

    visualLine = max(0, firstVisibleLine - bufferLines);

    // Process cursors and find indent ranges
    for (final cursor in cursors) {
      if (cursor.line >= startLine &&
          cursor.line < lines.length &&
          !editorState.isLineHidden(cursor.line)) {
        _processCursor(cursor, lines, highlightedIndentRanges,
            isClosestIndentLevel, firstVisibleLine, lastVisibleLine);
      }
    }

    // Draw indent lines
    for (int i = startLine; i < lines.length; i++) {
      if (!editorState.isLineHidden(i)) {
        _drawIndentLinesForLine(
            canvas, i, lines, highlightedIndentRanges, visualLine);
        visualLine++;
        if (visualLine > lastVisibleLine + bufferLines) break;
      }
    }
  }

  void _processCursor(
      Cursor cursor,
      List<String> lines,
      Map<int, Set<int>> highlightedIndentRanges,
      Map<int, bool> isClosestIndentLevel,
      int firstVisibleLine,
      int lastVisibleLine) {
    final line = lines[cursor.line];
    final leadingSpaces = _countLeadingSpaces(line);
    final closestIndentLevel =
        _findClosestIndentLevel(leadingSpaces, cursor.column);

    if (closestIndentLevel >= 0) {
      final blockRange = _findBlockBoundaries(lines, cursor.line,
          closestIndentLevel, firstVisibleLine, lastVisibleLine);
      highlightedIndentRanges
          .putIfAbsent(closestIndentLevel, () => {})
          .addAll(blockRange);
      isClosestIndentLevel[closestIndentLevel] = true;
    }
  }

  int _findClosestIndentLevel(int leadingSpaces, int cursorColumn) {
    int closestIndentLevel = -1;
    int minDistance = double.maxFinite.toInt();

    for (int space = 0; space <= leadingSpaces; space += 4) {
      int distance = (cursorColumn - space).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndentLevel = space;
      }
    }

    if (leadingSpaces > 0) {
      int lastIndentLevel = (leadingSpaces ~/ 4) * 4;
      int distanceToLast = (cursorColumn - lastIndentLevel).abs();
      if (distanceToLast < minDistance) {
        closestIndentLevel = lastIndentLevel;
      }
    }

    return closestIndentLevel;
  }

  void _drawIndentLinesForLine(Canvas canvas, int lineIndex, List<String> lines,
      Map<int, Set<int>> highlightedIndentRanges, int visualLine) {
    final line = lines[lineIndex];
    final leadingSpaces = line.trim().isEmpty
        ? _getPreviousNonEmptyLineIndent(lines, lineIndex)
        : _countLeadingSpaces(line);

    for (int space = 0; space < leadingSpaces; space += 4) {
      if (line.isNotEmpty && !line.startsWith(' ')) continue;
      final xPosition = space * editorLayoutService.config.charWidth;

      _drawIndentLine(
        canvas,
        xPosition,
        visualLine,
        isCurrentIndent: highlightedIndentRanges.containsKey(space) &&
            highlightedIndentRanges[space]!.contains(lineIndex),
      );
    }
  }

  int _getPreviousNonEmptyLineIndent(List<String> lines, int currentLine) {
    int line = currentLine - 1;
    while (line >= 0) {
      if (!editorState.isLineHidden(line) && lines[line].trim().isNotEmpty) {
        return _countLeadingSpaces(lines[line]);
      }
      line--;
    }
    return 0;
  }

  Set<int> _findBlockBoundaries(List<String> lines, int cursorLine,
      int indentLevel, int firstVisibleLine, int lastVisibleLine) {
    Set<int> blockLines = {};

    // Search upward
    int upLine = cursorLine;
    while (upLine >= firstVisibleLine) {
      if (!editorState.isLineHidden(upLine)) {
        final lineIndent = _countLeadingSpaces(lines[upLine]);
        if (lineIndent < indentLevel) break;
        blockLines.add(upLine);
        if (lineIndent == indentLevel && upLine > 0) {
          int prevLine = _getPreviousVisibleLine(upLine - 1);
          if (prevLine >= 0 &&
              _countLeadingSpaces(lines[prevLine]) < indentLevel) {
            break;
          }
        }
      }
      upLine = _getPreviousVisibleLine(upLine - 1);
    }

    // Search downward
    int downLine = _getNextVisibleLine(cursorLine + 1);
    while (downLine <= lastVisibleLine && downLine < lines.length) {
      if (!editorState.isLineHidden(downLine)) {
        final lineIndent = _countLeadingSpaces(lines[downLine]);
        if (lineIndent < indentLevel) break;
        blockLines.add(downLine);
        if (lineIndent == indentLevel && downLine < lines.length - 1) {
          int nextLine = _getNextVisibleLine(downLine + 1);
          if (nextLine < lines.length &&
              _countLeadingSpaces(lines[nextLine]) < indentLevel) {
            break;
          }
        }
      }
      downLine = _getNextVisibleLine(downLine + 1);
    }

    return blockLines;
  }

  int _getNextVisibleLine(int line) {
    while (
        line < editorState.buffer.lineCount && editorState.isLineHidden(line)) {
      line++;
    }
    return line;
  }

  int _getPreviousVisibleLine(int line) {
    while (line >= 0 && editorState.isLineHidden(line)) {
      line--;
    }
    return line;
  }

  void _drawIndentLine(Canvas canvas, double left, int lineNumber,
      {bool isCurrentIndent = false}) {
    const double lineOffset = 1;
    final theme = editorConfigService.themeService.currentTheme;

    final paint = Paint()
      ..color = theme != null
          ? isCurrentIndent
              ? theme.indentLineColor.withOpacity(0.4)
              : theme.indentLineColor
          : Colors.black.withOpacity(isCurrentIndent ? 0.4 : 0.2)
      ..strokeWidth = isCurrentIndent ? 2.0 : 1.0;

    canvas.drawLine(
        Offset(left + lineOffset,
            lineNumber * editorLayoutService.config.lineHeight),
        Offset(
            left + lineOffset,
            lineNumber * editorLayoutService.config.lineHeight +
                editorLayoutService.config.lineHeight),
        paint);
  }

  int _countLeadingSpaces(String line) {
    int count = 0;
    for (int j = 0; j < line.length; j++) {
      if (line[j] == ' ') {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  @override
  bool shouldRepaint(covariant IndentationPainter oldDelegate) {
    return editorState.buffer.version !=
            oldDelegate.editorState.buffer.version ||
        editorState.foldingRanges != oldDelegate.editorState.foldingRanges ||
        !_compareCursors(editorState.editorCursorManager.cursors,
            oldDelegate.editorState.editorCursorManager.cursors);
  }

  bool _compareCursors(List<Cursor> cursors1, List<Cursor> cursors2) {
    if (cursors1.length != cursors2.length) return false;
    for (int i = 0; i < cursors1.length; i++) {
      if (cursors1[i].line != cursors2[i].line ||
          cursors1[i].column != cursors2[i].column) {
        return false;
      }
    }
    return true;
  }
}
