import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class BracketMatchPainter extends EditorPainterBase {
  final List<Cursor> cursors;
  final EditorState editorState;
  late final Paint _bracketPaint;

  BracketMatchPainter({
    required this.cursors,
    required this.editorState,
    required super.editorLayoutService,
    required super.editorConfigService,
  }) {
    _bracketPaint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
  }

  int? _getFoldStartLine(int line) {
    for (var entry in editorState.buffer.foldedRanges.entries) {
      if (line >= entry.key && line <= entry.value) {
        return entry.key;
      }
    }
    return null;
  }

  int? _getFoldEndLine(int line) {
    for (var entry in editorState.buffer.foldedRanges.entries) {
      if (line >= entry.key && line <= entry.value) {
        return entry.value;
      }
    }
    return null;
  }

  void _handleFoldedRegions(
      int startLine, int endLine, void Function() callback) {
    int currentLine = startLine;
    while (currentLine <= endLine) {
      if (editorState.foldingState.isLineHidden(currentLine)) {
        var foldStartLine = _getFoldStartLine(currentLine);
        var foldEndLine = _getFoldEndLine(currentLine);
        if (foldStartLine != null && foldEndLine != null) {
          callback();
          currentLine = foldEndLine + 1;
        } else {
          currentLine++;
        }
      } else {
        callback();
        currentLine++;
      }
    }
  }

  Position? _findMatchingBracketPosition(
      int startLine, int startColumn, String bracket) {
    final isOpen = _isOpenBracket(bracket);
    final matchingChar = _getMatchingBracket(bracket);
    if (matchingChar == null) return null;

    int nestLevel = 1;

    if (isOpen) {
      // Search forward
      int currentLine = startLine;
      while (currentLine < editorState.buffer.lineCount) {
        if (editorState.foldingState.isLineHidden(currentLine)) {
          var foldEnd = _getFoldEndLine(currentLine);
          if (foldEnd != null) {
            // Check the last visible line of the fold
            final lastVisibleLine = editorState.buffer.getLine(foldEnd);
            int columnStart = 0;
            for (int col = columnStart; col < lastVisibleLine.length; col++) {
              final char = lastVisibleLine[col];
              if (char == bracket) nestLevel++;
              if (char == matchingChar) nestLevel--;

              if (nestLevel == 0) {
                return Position(line: foldEnd, column: col);
              }
            }
            currentLine = foldEnd + 1;
            continue;
          }
        }

        final line = editorState.buffer.getLine(currentLine);
        int columnStart = currentLine == startLine ? startColumn + 1 : 0;

        for (int col = columnStart; col < line.length; col++) {
          final char = line[col];
          if (char == bracket) nestLevel++;
          if (char == matchingChar) nestLevel--;

          if (nestLevel == 0) {
            return Position(line: currentLine, column: col);
          }
        }
        currentLine++;
      }
    } else {
      // Search backward
      int currentLine = startLine;
      while (currentLine >= 0) {
        if (editorState.foldingState.isLineHidden(currentLine)) {
          var foldStart = _getFoldStartLine(currentLine);
          if (foldStart != null) {
            // Check the first visible line of the fold
            final firstVisibleLine = editorState.buffer.getLine(foldStart);
            int columnStart = firstVisibleLine.length - 1;
            for (int col = columnStart; col >= 0; col--) {
              final char = firstVisibleLine[col];
              if (char == bracket) nestLevel++;
              if (char == matchingChar) nestLevel--;

              if (nestLevel == 0) {
                return Position(line: foldStart, column: col);
              }
            }
            currentLine = foldStart - 1;
            continue;
          }
        }

        final line = editorState.buffer.getLine(currentLine);
        int columnStart =
            currentLine == startLine ? startColumn - 1 : line.length - 1;

        for (int col = columnStart; col >= 0; col--) {
          final char = line[col];
          if (char == bracket) nestLevel++;
          if (char == matchingChar) nestLevel--;

          if (nestLevel == 0) {
            return Position(line: currentLine, column: col);
          }
        }
        currentLine--;
      }
    }

    return null;
  }

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  }) {
    if (cursors.isEmpty) return;

    final config = editorLayoutService.config;
    final theme = editorConfigService.themeService.currentTheme;
    _bracketPaint.color =
        theme?.primary.withOpacity(0.3) ?? Colors.blue.withOpacity(0.3);

    for (final cursor in cursors) {
      final line = editorState.buffer.getLine(cursor.line);
      if (line.isEmpty) continue; // Skip empty lines

      Position? matchingPosition;
      Position? bracketPosition;

      final positions = <int>[];
      if (cursor.column > 0 && cursor.column <= line.length) {
        positions.add(cursor.column - 1); // Before cursor
      }
      if (cursor.column < line.length) {
        positions.add(cursor.column); // At cursor
      }

      for (final pos in positions) {
        if (pos < 0 || pos >= line.length) continue;

        final char = line[pos];
        if (_isBracket(char)) {
          final potentialMatch = _findMatchingBracketPosition(
            cursor.line,
            pos,
            char,
          );
          if (potentialMatch != null) {
            bracketPosition = Position(line: cursor.line, column: pos);
            matchingPosition = potentialMatch;
            break;
          }
        }
      }

      if (bracketPosition != null && matchingPosition != null) {
        _paintBracket(canvas, size, bracketPosition, firstVisibleLine);
        _paintBracket(canvas, size, matchingPosition, firstVisibleLine);
      }
    }
  }

  void _paintBracket(
      Canvas canvas, Size size, Position position, int firstVisibleLine) {
    final config = editorLayoutService.config;
    final visualLine = _getVisualLine(position.line);

    if (visualLine < firstVisibleLine) return;

    final yOffset = (visualLine) * config.lineHeight;
    final xOffset = position.column * config.charWidth;

    final bracketRect = Rect.fromLTWH(
      xOffset,
      yOffset,
      config.charWidth,
      config.lineHeight,
    );

    if (_isWithinBounds(bracketRect, size)) {
      canvas.drawRect(bracketRect, _bracketPaint);
    }
  }

  void paintBracketHighlight(
      Canvas canvas, Size size, int firstVisibleLine, int lastVisibleLine) {
    final config = editorLayoutService.config;
    final theme = editorConfigService.themeService.currentTheme;
    _bracketPaint.color =
        theme?.primary.withOpacity(0.3) ?? Colors.blue.withOpacity(0.3);

    for (final cursor in cursors) {
      if (cursor.line < firstVisibleLine || cursor.line > lastVisibleLine) {
        continue;
      }

      final line = editorState.buffer.getLine(cursor.line);
      if (line.isEmpty) continue; // Skip empty lines

      Position? matchingPosition;
      Position? bracketPosition;

      final positions = <int>[];
      if (cursor.column > 0 && cursor.column <= line.length) {
        positions.add(cursor.column - 1); // Before cursor
      }
      if (cursor.column < line.length) {
        positions.add(cursor.column); // At cursor
      }

      for (final pos in positions) {
        if (pos < 0 || pos >= line.length) continue;

        final char = line[pos];
        if (_isBracket(char)) {
          final potentialMatch = _findMatchingBracketPosition(
            cursor.line,
            pos,
            char,
          );
          if (potentialMatch != null) {
            bracketPosition = Position(line: cursor.line, column: pos);
            matchingPosition = potentialMatch;
            break;
          }
        }
      }

      if (bracketPosition != null && matchingPosition != null) {
        // Calculate visual positions accounting for folded regions
        int visualBracketLine = _getVisualLine(bracketPosition.line);
        int visualMatchingLine = _getVisualLine(matchingPosition.line);

        // Draw bracket at cursor position
        final bracketRect = Rect.fromLTWH(
          config.charWidth * bracketPosition.column,
          (visualBracketLine - firstVisibleLine) * config.lineHeight,
          config.charWidth,
          config.lineHeight,
        );
        if (_isWithinBounds(bracketRect, size)) {
          canvas.drawRect(bracketRect, _bracketPaint);
        }

        // Draw matching bracket
        final matchingRect = Rect.fromLTWH(
          config.charWidth * matchingPosition.column,
          (visualMatchingLine - firstVisibleLine) * config.lineHeight,
          config.charWidth,
          config.lineHeight,
        );
        if (_isWithinBounds(matchingRect, size)) {
          canvas.drawRect(matchingRect, _bracketPaint);
        }
      }
    }
  }

  int _getVisualLine(int bufferLine) {
    int visualLine = 0;
    for (int i = 0; i < bufferLine; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        visualLine++;
      }
    }
    return visualLine;
  }

  bool _isWithinBounds(Rect rect, Size size) {
    return rect.left >= 0 &&
        rect.top >= 0 &&
        rect.right <= size.width &&
        rect.bottom <= size.height;
  }

  bool _isBracket(String char) {
    return char == '(' ||
        char == ')' ||
        char == '[' ||
        char == ']' ||
        char == '{' ||
        char == '}';
  }

  String? _getMatchingBracket(String char) {
    switch (char) {
      case '(':
        return ')';
      case ')':
        return '(';
      case '[':
        return ']';
      case ']':
        return '[';
      case '{':
        return '}';
      case '}':
        return '{';
      default:
        return null;
    }
  }

  bool _isOpenBracket(String char) {
    return char == '(' || char == '[' || char == '{';
  }

  @override
  bool shouldRepaint(covariant BracketMatchPainter oldDelegate) {
    return !listEquals(cursors, oldDelegate.cursors) ||
        editorState != oldDelegate.editorState ||
        editorLayoutService.config != oldDelegate.editorLayoutService.config;
  }
}
