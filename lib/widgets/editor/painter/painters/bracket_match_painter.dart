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

  @override
  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  }) {
    if (cursors.isEmpty) return;
    paintBracketHighlight(canvas, size, firstVisibleLine, lastVisibleLine);
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

      Position? matchingPosition;
      Position? bracketPosition;

      final positions = [
        if (cursor.column > 0) cursor.column - 1, // Before cursor
        if (cursor.column < line.length) cursor.column, // At cursor
      ];

      for (final pos in positions) {
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
        final bracketRect = Rect.fromLTWH(
          config.charWidth * bracketPosition.column,
          bracketPosition.line * config.lineHeight,
          config.charWidth,
          config.lineHeight,
        );

        if (_isWithinBounds(bracketRect, size)) {
          canvas.drawRect(bracketRect, _bracketPaint);
        }

        final matchingRect = Rect.fromLTWH(
          config.charWidth * matchingPosition.column,
          matchingPosition.line * config.lineHeight,
          config.charWidth,
          config.lineHeight,
        );

        if (_isWithinBounds(matchingRect, size)) {
          canvas.drawRect(matchingRect, _bracketPaint);
        }
      }
    }
  }

  bool _isWithinBounds(Rect rect, Size size) {
    return rect.left < size.width && rect.top < size.height;
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
        editorState != oldDelegate.editorState;
  }
}
