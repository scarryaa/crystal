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

    // Adjust visible lines to account for folded regions
    int adjustedFirstLine = _getNextVisibleLine(firstVisibleLine);
    int adjustedLastLine = _getPreviousVisibleLine(lastVisibleLine);

    for (final cursor in cursors) {
      if (cursor.line >= 0 &&
          cursor.line < lines.length &&
          !editorState.foldingState.isLineHidden(cursor.line)) {
        final line = lines[cursor.line];
        final leadingSpaces = _countLeadingSpaces(line);
        final cursorColumn = cursor.column;

        // Find the closest indent level by checking all possible indent levels
        int closestIndentLevel = -1;
        int minDistance = double.maxFinite.toInt();

        // Check all possible indent levels (in steps of 4)
        for (int space = 0; space <= leadingSpaces; space += 4) {
          int distance = (cursorColumn - space).abs();
          if (distance < minDistance) {
            minDistance = distance;
            closestIndentLevel = space;
          }
        }

        // Add an additional check for the last indent level
        if (leadingSpaces > 0) {
          int lastIndentLevel = (leadingSpaces ~/ 4) * 4;
          int distanceToLast = (cursorColumn - lastIndentLevel).abs();
          if (distanceToLast < minDistance) {
            minDistance = distanceToLast;
            closestIndentLevel = lastIndentLevel;
          }
        }

        if (closestIndentLevel >= 0) {
          final blockRange = _findBlockBoundaries(
            lines,
            cursor.line,
            closestIndentLevel,
            adjustedFirstLine,
            adjustedLastLine,
          );

          highlightedIndentRanges
              .putIfAbsent(closestIndentLevel, () => {})
              .addAll(blockRange);
          isClosestIndentLevel[closestIndentLevel] = true;
        }
      }
    }

    // Draw the indent lines only for visible lines
    for (int i = adjustedFirstLine; i <= adjustedLastLine; i++) {
      if (i >= 0 &&
          i < lines.length &&
          !editorState.foldingState.isLineHidden(i)) {
        final line = lines[i];
        final leadingSpaces = line.trim().isEmpty
            ? _getPreviousNonEmptyLineIndent(lines, i)
            : _countLeadingSpaces(line);

        for (int space = 0; space < leadingSpaces; space += 4) {
          if (line.isNotEmpty && !line.startsWith(' ')) continue;
          final xPosition = space * editorLayoutService.config.charWidth;

          _drawIndentLine(
            canvas,
            xPosition,
            _getVisibleLineIndex(i), // Adjust for folded lines
            isCurrentIndent: highlightedIndentRanges.containsKey(space) &&
                highlightedIndentRanges[space]!.contains(i),
          );
        }
      }
    }
  }

  int _getPreviousNonEmptyLineIndent(List<String> lines, int currentLine) {
    int line = currentLine - 1;
    while (line >= 0) {
      if (!editorState.foldingState.isLineHidden(line) &&
          lines[line].trim().isNotEmpty) {
        return _countLeadingSpaces(lines[line]);
      }
      line--;
    }
    return 0;
  }

  Set<int> _findBlockBoundaries(
    List<String> lines,
    int cursorLine,
    int indentLevel,
    int firstVisibleLine,
    int lastVisibleLine,
  ) {
    Set<int> blockLines = {};

    // Search upward
    int upLine = cursorLine;
    while (upLine >= firstVisibleLine) {
      if (editorState.foldingState.isLineHidden(upLine)) {
        upLine = _getPreviousVisibleLine(upLine - 1);
        continue;
      }

      final lineIndent = _countLeadingSpaces(lines[upLine]);

      if (lineIndent < indentLevel) break;

      if (lineIndent == indentLevel && upLine > 0) {
        int prevLine = _getPreviousVisibleLine(upLine - 1);
        if (prevLine >= 0) {
          final prevLineIndent = _countLeadingSpaces(lines[prevLine]);
          if (prevLineIndent < indentLevel) {
            blockLines.add(upLine);
            break;
          }
        }
      }

      blockLines.add(upLine);
      upLine = _getPreviousVisibleLine(upLine - 1);
    }

    // Search downward
    int downLine = cursorLine + 1;
    while (downLine <= lastVisibleLine && downLine < lines.length) {
      if (editorState.foldingState.isLineHidden(downLine)) {
        downLine = _getNextVisibleLine(downLine + 1);
        continue;
      }

      final lineIndent = _countLeadingSpaces(lines[downLine]);

      if (lineIndent < indentLevel) break;

      if (lineIndent == indentLevel && downLine < lines.length - 1) {
        int nextLine = _getNextVisibleLine(downLine + 1);
        if (nextLine < lines.length) {
          final nextLineIndent = _countLeadingSpaces(lines[nextLine]);
          if (nextLineIndent < indentLevel) {
            blockLines.add(downLine);
            break;
          }
        }
      }

      blockLines.add(downLine);
      downLine = _getNextVisibleLine(downLine + 1);
    }

    return blockLines;
  }

  // Helper methods for handling folded regions
  int _getNextVisibleLine(int line) {
    while (line < editorState.buffer.lineCount &&
        editorState.foldingState.isLineHidden(line)) {
      line++;
    }
    return line;
  }

  int _getPreviousVisibleLine(int line) {
    while (line >= 0 && editorState.foldingState.isLineHidden(line)) {
      line--;
    }
    return line;
  }

  int _getVisibleLineIndex(int actualLine) {
    int visibleIndex = 0;
    for (int i = 0; i < actualLine; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        visibleIndex++;
      }
    }
    return visibleIndex;
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
        editorState.foldingState != oldDelegate.editorState.foldingState ||
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
