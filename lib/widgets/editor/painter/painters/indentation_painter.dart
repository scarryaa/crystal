import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/material.dart';

class IndentationPainter extends EditorPainterBase {
  final EditorState editorState;
  final double viewportHeight;

  static const defaultTabSize = 4;
  static const supportedIndentTypes = ['spaces', 'tabs'];

  IndentationPainter({
    required this.editorState,
    required this.viewportHeight,
    required super.editorLayoutService,
    required super.editorConfigService,
  });

  bool _hasMixedIndentation(String line) {
    // Only check the leading whitespace
    int i = 0;
    bool hasSpaces = false;
    bool hasTabs = false;

    // Count only leading whitespace
    while (i < line.length && (line[i] == ' ' || line[i] == '\t')) {
      if (line[i] == ' ') hasSpaces = true;
      if (line[i] == '\t') hasTabs = true;
      i++;
    }

    // Mixed indentation is only when both tabs and spaces are used for indentation
    return hasSpaces && hasTabs;
  }

  void _drawDottedLine(Canvas canvas, Offset start, Offset end, Paint paint) {
    const double dashLength = 3;
    const double spaceLength = 3;

    double distance = (end - start).distance;
    int numberOfDashes = (distance / (dashLength + spaceLength)).floor();

    Offset direction = (end - start) / distance;

    for (int i = 0; i < numberOfDashes; i++) {
      double startFraction = i * (dashLength + spaceLength) / distance;
      double endFraction =
          (i * (dashLength + spaceLength) + dashLength) / distance;

      if (endFraction > 1.0) endFraction = 1.0;

      canvas.drawLine(
        start + direction * (startFraction * distance),
        start + direction * (endFraction * distance),
        paint,
      );
    }
  }

  Color _getIndentLineColor(
      dynamic theme, bool isCurrentIndent, bool isMixedIndent) {
    if (theme != null) {
      if (isMixedIndent) {
        return Colors.orange.shade400.withOpacity(0.8);
      }
      Color baseColor = theme.indentLineColor;
      return isCurrentIndent
          ? baseColor.withOpacity(0.6)
          : baseColor.withOpacity(0.3);
    }
    return Colors.grey.withOpacity(isCurrentIndent ? 0.6 : 0.3);
  }

  void _drawIndentLine(Canvas canvas, Size size, double left, int lineNumber,
      {bool isCurrentIndent = false, bool isMixedIndent = false}) {
    const double lineOffset = 1;
    final paint = Paint()
      ..color = _getIndentLineColor(
          editorConfigService.themeService.currentTheme,
          isCurrentIndent,
          isMixedIndent)
      ..strokeWidth = isMixedIndent ? 1.5 : (isCurrentIndent ? 1.5 : 1.0);

    final lineHeight = editorLayoutService.config.lineHeight;
    final startY = lineNumber * lineHeight;
    final endY = startY + lineHeight;

    if (isMixedIndent) {
      _drawDottedLine(
        canvas,
        Offset(left + lineOffset, startY),
        Offset(left + lineOffset, endY),
        paint,
      );

      final bgPaint = Paint()
        ..color = Colors.orange.withOpacity(0.05)
        ..style = PaintingStyle.fill;

      canvas.drawRect(
        Rect.fromLTWH(0, startY, size.width, lineHeight),
        bgPaint,
      );
    } else {
      canvas.drawLine(
        Offset(left + lineOffset, startY),
        Offset(left + lineOffset, endY),
        paint,
      );
    }
  }

  (int, bool) _countIndentation(String line) {
    int spaceCount = 0;
    int tabCount = 0;
    bool isMixed = false;

    // Only count leading whitespace
    for (int i = 0; i < line.length; i++) {
      if (line[i] == ' ') {
        spaceCount++;
        if (tabCount > 0) isMixed = true;
      } else if (line[i] == '\t') {
        tabCount++;
        if (spaceCount > 0) isMixed = true;
      } else {
        break;
      }
    }

    // Convert tabs to spaces based on tab size and return both count and mixed status
    return (spaceCount + (tabCount * defaultTabSize), isMixed);
  }

  int _drawIndentLinesForLine(
    Canvas canvas,
    Size size,
    int lineIndex,
    List<String> lines,
    Map<int, Set<int>> highlightedIndentRanges,
    int visualLine,
    int previousIndentContext,
  ) {
    final line = lines[lineIndex];
    final (currentIndent, isMixed) = _countIndentation(line);

    // For empty lines, use contextual indent but don't show mixed warning
    if (line.trim().isEmpty) {
      final contextIndent =
          _getContextualIndent(lines, lineIndex, previousIndentContext);

      for (int space = 0; space < contextIndent; space += defaultTabSize) {
        final xPosition = space * editorLayoutService.config.charWidth;
        final isHighlighted =
            _isIndentHighlighted(space, lineIndex, highlightedIndentRanges);

        _drawIndentLine(
          canvas,
          size,
          xPosition,
          visualLine,
          isCurrentIndent: isHighlighted,
        );
      }
      return contextIndent;
    }

    // For non-empty lines, draw indent guides with mixed indentation warning if needed
    for (int space = 0; space < currentIndent; space += defaultTabSize) {
      final xPosition = space * editorLayoutService.config.charWidth;
      final isHighlighted =
          _isIndentHighlighted(space, lineIndex, highlightedIndentRanges);

      _drawIndentLine(
        canvas,
        size,
        xPosition,
        visualLine,
        isCurrentIndent: isHighlighted,
        isMixedIndent: isMixed,
      );
    }

    return currentIndent;
  }

  @override
  void paint(Canvas canvas, Size size,
      {required int firstVisibleLine, required int lastVisibleLine}) {
    final lines = editorState.buffer.lines;
    final cursors = editorState.editorCursorManager.cursors;
    Map<int, Set<int>> highlightedIndentRanges = {};
    Map<int, bool> isClosestIndentLevel = {};

    const bufferLines = 10;
    int visualLine = 0;
    int startLine = _findStartLine(lines, firstVisibleLine, bufferLines);

    visualLine = max(0, firstVisibleLine - bufferLines);

    _processVisibleCursors(
      cursors,
      startLine,
      lines,
      highlightedIndentRanges,
      isClosestIndentLevel,
      firstVisibleLine,
      lastVisibleLine,
    );

    _drawAllIndentLines(
      canvas,
      size,
      startLine,
      lines,
      highlightedIndentRanges,
      visualLine,
      lastVisibleLine,
      bufferLines,
    );
  }

  int _findStartLine(
      List<String> lines, int firstVisibleLine, int bufferLines) {
    int visualLine = 0;
    int startLine = 0;

    while (startLine < lines.length &&
        visualLine < firstVisibleLine - bufferLines) {
      if (!editorState.isLineHidden(startLine)) {
        visualLine++;
      }
      startLine++;
    }

    return startLine;
  }

  void _processVisibleCursors(
    List<Cursor> cursors,
    int startLine,
    List<String> lines,
    Map<int, Set<int>> highlightedIndentRanges,
    Map<int, bool> isClosestIndentLevel,
    int firstVisibleLine,
    int lastVisibleLine,
  ) {
    for (final cursor in cursors) {
      if (_isCursorVisible(cursor, startLine, lines)) {
        _processCursor(
          cursor,
          lines,
          highlightedIndentRanges,
          isClosestIndentLevel,
          firstVisibleLine,
          lastVisibleLine,
        );
      }
    }
  }

  bool _isCursorVisible(Cursor cursor, int startLine, List<String> lines) {
    return cursor.line >= startLine &&
        cursor.line < lines.length &&
        !editorState.isLineHidden(cursor.line);
  }

  void _drawAllIndentLines(
    Canvas canvas,
    Size size,
    int startLine,
    List<String> lines,
    Map<int, Set<int>> highlightedIndentRanges,
    int visualLine,
    int lastVisibleLine,
    int bufferLines,
  ) {
    int currentIndentContext = 0;

    for (int i = startLine; i < lines.length; i++) {
      if (!editorState.isLineHidden(i)) {
        currentIndentContext = _drawIndentLinesForLine(
          canvas,
          size,
          i,
          lines,
          highlightedIndentRanges,
          visualLine,
          currentIndentContext,
        );
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
    int lastVisibleLine,
  ) {
    final line = lines[cursor.line];
    final leadingSpaces = _countLeadingSpaces(line);
    final closestIndentLevel =
        _findClosestIndentLevel(leadingSpaces, cursor.column);

    if (closestIndentLevel >= 0) {
      final blockRange = _findBlockBoundaries(
        lines,
        cursor.line,
        closestIndentLevel,
        firstVisibleLine,
        lastVisibleLine,
      );

      highlightedIndentRanges
          .putIfAbsent(closestIndentLevel, () => {})
          .addAll(blockRange);
      isClosestIndentLevel[closestIndentLevel] = true;
    }
  }

  int _findClosestIndentLevel(int leadingSpaces, int cursorColumn) {
    if (leadingSpaces == 0) return -1;

    int tabSize = 4;
    int closestIndentLevel = -1;
    int minDistance = double.maxFinite.toInt();

    // Calculate all possible indent levels
    List<int> possibleIndents = [];
    for (int i = 0; i <= leadingSpaces ~/ tabSize; i++) {
      possibleIndents.add(i * tabSize);
    }

    // Find the closest indent level to cursor position
    for (int indent in possibleIndents) {
      int distance = (cursorColumn - indent).abs();
      if (distance < minDistance) {
        minDistance = distance;
        closestIndentLevel = indent;
      }
    }

    // Special handling for cursor positions beyond the last indent level
    if (cursorColumn > leadingSpaces) {
      int lastIndentLevel = (leadingSpaces ~/ tabSize) * tabSize;
      if ((cursorColumn - lastIndentLevel).abs() <= minDistance) {
        closestIndentLevel = lastIndentLevel;
      }
    }

    return closestIndentLevel;
  }

  int _getContextualIndent(
    List<String> lines,
    int currentLine,
    int previousIndentContext,
  ) {
    // Look ahead for next non-empty line
    int nextIndent = _getNextNonEmptyLineIndent(lines, currentLine);
    // Look back for previous non-empty line
    int prevIndent = _getPreviousNonEmptyLineIndent(lines, currentLine);

    // Use the smaller of the surrounding indents to avoid over-indentation
    if (nextIndent > 0 && prevIndent > 0) {
      return min(nextIndent, prevIndent);
    }

    // Fall back to previous context if no clear indication
    return nextIndent > 0
        ? nextIndent
        : prevIndent > 0
            ? prevIndent
            : previousIndentContext;
  }

  int _getNextNonEmptyLineIndent(List<String> lines, int currentLine) {
    int line = currentLine + 1;
    while (line < lines.length) {
      if (!editorState.isLineHidden(line) && lines[line].trim().isNotEmpty) {
        return _countLeadingSpaces(lines[line]);
      }
      line++;
    }
    return 0;
  }

  bool _isIndentHighlighted(
    int space,
    int lineIndex,
    Map<int, Set<int>> highlightedIndentRanges,
  ) {
    return highlightedIndentRanges.containsKey(space) &&
        highlightedIndentRanges[space]!.contains(lineIndex);
  }

  int _countLeadingSpaces(String line) {
    int count = 0;
    for (int i = 0; i < line.length && line[i] == ' '; i++) {
      count++;
    }
    return count;
  }

  @override
  bool shouldRepaint(covariant IndentationPainter oldDelegate) {
    return editorState.buffer.version !=
            oldDelegate.editorState.buffer.version ||
        editorState.foldingRanges != oldDelegate.editorState.foldingRanges ||
        !_compareCursors(
          editorState.editorCursorManager.cursors,
          oldDelegate.editorState.editorCursorManager.cursors,
        );
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
}
