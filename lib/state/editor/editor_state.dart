import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  Cursor cursor = Cursor(0, 0);
  EditorScrollState scrollState = EditorScrollState();
  Selection? selection;
  int? anchorLine;
  int? anchorColumn;
  VoidCallback resetGutterScroll;
  bool showCaret = true;
  CursorShape cursorShape = CursorShape.bar;
  String path = '';

  EditorState({required this.resetGutterScroll, this.path = ''});

  double getGutterWidth() {
    return math.max((lines.length.toString().length * 10.0) + 40.0, 48.0);
  }

  void toggleCaret() {
    showCaret = !showCaret;
    notifyListeners();
  }

  void startSelection() {
    // Store the anchor point when starting selection
    anchorLine = cursor.line;
    anchorColumn = cursor.column;

    selection = Selection(
        startLine: cursor.line,
        endLine: cursor.line,
        startColumn: cursor.column,
        endColumn: cursor.column);
  }

  void updateSelection() {
    if (selection == null || anchorLine == null || anchorColumn == null) return;

    // Compare cursor position with anchor to determine direction
    if (cursor.line < anchorLine! ||
        (cursor.line == anchorLine! && cursor.column < anchorColumn!)) {
      // Selecting backwards
      selection = Selection(
          startLine: cursor.line,
          endLine: anchorLine!,
          startColumn: cursor.column,
          endColumn: anchorColumn!);
    } else {
      // Selecting forwards
      selection = Selection(
          startLine: anchorLine!,
          endLine: cursor.line,
          startColumn: anchorColumn!,
          endColumn: cursor.column);
    }
  }

  void clearSelection() {
    selection = null;
    anchorLine = null;
    anchorColumn = null;
    notifyListeners();
  }

  void selectAll() {
    anchorLine = lines.length - 1;
    anchorColumn = lines.last.length;
    cursor.line = 0;
    cursor.column = 0;
    selection = Selection(
        startLine: 0,
        endLine: lines.length - 1,
        startColumn: 0,
        endColumn: lines.last.length);
    notifyListeners();
  }

  String getSelectedText() {
    if (selection == null) return '';
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line selection
      return lines[_selection.startLine]
          .substring(_selection.startColumn, _selection.endColumn);
    }

    // Multi-line selection
    StringBuffer result = StringBuffer();

    // First line
    result.write(lines[_selection.startLine].substring(_selection.startColumn));
    result.write('\n');

    // Middle lines
    for (int i = _selection.startLine + 1; i < _selection.endLine; i++) {
      result.write(lines[i]);
      result.write('\n');
    }

    // Last line
    result.write(lines[_selection.endLine].substring(0, _selection.endColumn));

    return result.toString();
  }

  void deleteSelection() {
    if (selection == null) return;
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line deletion
      lines[_selection.startLine] =
          lines[_selection.startLine].substring(0, _selection.startColumn) +
              lines[_selection.startLine].substring(_selection.endColumn);
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    } else {
      // Multi-line deletion
      String startText =
          lines[_selection.startLine].substring(0, _selection.startColumn);
      String endText =
          lines[_selection.endLine].substring(_selection.endColumn);

      // Combine first and last lines
      lines[_selection.startLine] = startText + endText;

      // Remove lines in between
      for (int i = 0; i < _selection.endLine - _selection.startLine; i++) {
        lines.removeAt(_selection.startLine + 1);
      }

      // Update cursor position
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    }

    clearSelection();
    version++;

    if (lines.isEmpty || (lines.length == 1 && lines[0].isEmpty)) {
      scrollState.updateVerticalScrollOffset(0);
      scrollState.updateHorizontalScrollOffset(0);
      resetGutterScroll();
    }

    notifyListeners();
  }

  void backspace() {
    if (selection != null) {
      deleteSelection();
      return;
    }

    if (cursor.column > 0) {
      // Check if we're deleting spaces at the start of a line
      String currentLine = lines[cursor.line];
      String beforeCursor = currentLine.substring(0, cursor.column);
      if (beforeCursor.endsWith('    ') && beforeCursor.trim().isEmpty) {
        // Delete entire tab (4 spaces)
        lines[cursor.line] = currentLine.substring(0, cursor.column - 4) +
            currentLine.substring(cursor.column);
        cursor.column -= 4;
      } else {
        // Normal single character deletion
        lines[cursor.line] = currentLine.substring(0, cursor.column - 1) +
            currentLine.substring(cursor.column);
        cursor.column--;
      }
    } else if (cursor.line > 0) {
      cursor.column = lines[cursor.line - 1].length;
      lines[cursor.line - 1] += lines[cursor.line];
      lines.removeAt(cursor.line);
      cursor.line--;
    }
    version++;
    notifyListeners();
  }

  void delete() {
    if (selection != null) {
      deleteSelection();
      return;
    }

    if (cursor.column < lines[cursor.line].length) {
      String currentLine = lines[cursor.line];
      String afterCursor = currentLine.substring(cursor.column);
      if (afterCursor.startsWith('    ') &&
          afterCursor.substring(4).trim().isEmpty) {
        // Delete entire tab (4 spaces)
        lines[cursor.line] = currentLine.substring(0, cursor.column) +
            currentLine.substring(cursor.column + 4);
      } else {
        // Normal single character deletion
        lines[cursor.line] = currentLine.substring(0, cursor.column) +
            currentLine.substring(cursor.column + 1);
      }
    } else if (cursor.line < lines.length - 1) {
      lines[cursor.line] += lines[cursor.line + 1];
      lines.removeAt(cursor.line + 1);
    }
    version++;
    notifyListeners();
  }

  void cut() {
    copy();
    deleteSelection();
    notifyListeners();
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: getSelectedText()));
  }

  Future<void> paste() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    if (selection != null) {
      deleteSelection();
    }

    List<String> pastedLines = data.text!.split('\n');

    if (pastedLines.length == 1) {
      // Single line paste
      lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
          pastedLines[0] +
          lines[cursor.line].substring(cursor.column);
      cursor.column += pastedLines[0].length;
    } else {
      // Multi-line paste
      String remainingText = lines[cursor.line].substring(cursor.column);

      // First line
      lines[cursor.line] =
          lines[cursor.line].substring(0, cursor.column) + pastedLines[0];

      // Middle lines
      for (int i = 1; i < pastedLines.length - 1; i++) {
        lines.insert(cursor.line + i, pastedLines[i]);
      }

      // Last line
      lines.insert(cursor.line + pastedLines.length - 1,
          pastedLines.last + remainingText);

      cursor.line += pastedLines.length - 1;
      cursor.column = pastedLines.last.length;
    }

    version++;
    notifyListeners();
  }

  void insertTab() {
    if (selection != null) {
      Selection _selection = selection!;

      // Add tab to each line in selection
      for (int i = _selection.startLine; i <= _selection.endLine; i++) {
        lines[i] = '    ${lines[i]}';

        // Adjust selection and cursor columns
        if (i == _selection.startLine) {
          _selection = Selection(
              startLine: _selection.startLine,
              endLine: _selection.endLine,
              startColumn: _selection.startColumn + 4,
              endColumn: _selection.endColumn + 4);
        }
        if (i == cursor.line) {
          cursor.column += 4;
        }
      }

      selection = _selection;
    } else {
      // Insert tab at cursor position
      insertChar('    ');
      cursor.column += 3;
    }

    version++;
    notifyListeners();
  }

  void backTab() {
    if (selection != null) {
      Selection _selection = selection!;

      // Remove tab from each line in selection
      for (int i = _selection.startLine; i <= _selection.endLine; i++) {
        if (lines[i].startsWith('    ')) {
          lines[i] = lines[i].substring(4);

          // Adjust selection and cursor columns
          if (i == _selection.startLine) {
            _selection = Selection(
                startLine: _selection.startLine,
                endLine: _selection.endLine,
                startColumn: math.max(0, _selection.startColumn - 4),
                endColumn: math.max(0, _selection.endColumn - 4));
          }
          if (i == cursor.line) {
            cursor.column = math.max(0, cursor.column - 4);
          }
        }
      }

      selection = _selection;
    } else {
      // Remove tab at cursor position if line starts with spaces
      String currentLine = lines[cursor.line];
      if (currentLine.startsWith('    ')) {
        lines[cursor.line] = currentLine.substring(4);
        cursor.column = math.max(0, cursor.column - 4);
      }
    }

    version++;
    notifyListeners();
  }

  void insertChar(String c) {
    if (selection != null) {
      deleteSelection();
    }

    lines[cursor.line] = lines[cursor.line].substring(0, cursor.column) +
        c +
        lines[cursor.line].substring(cursor.column);
    cursor.column++;
    version++;
    notifyListeners();
  }

  bool handleSpecialKeys(bool isControlPressed, LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.add:
        if (isControlPressed) {
          EditorConstants.fontSize += 2.0;
          EditorConstants.lineHeight =
              EditorConstants.fontSize * EditorConstants.lineHeightRatio;
          notifyListeners();
          return true;
        }
      case LogicalKeyboardKey.minus:
        if (isControlPressed) {
          if (EditorConstants.fontSize > 8.0) {
            EditorConstants.fontSize -= 2.0;
            EditorConstants.lineHeight =
                EditorConstants.fontSize * EditorConstants.lineHeightRatio;

            notifyListeners();
          }
          return true;
        }
      case LogicalKeyboardKey.keyS:
        if (isControlPressed) {
          FileService.saveFile(path, lines.join('\n'));
          return true;
        }
    }

    return false;
  }

  void handleTap(double dy, double dx, Function(String line) measureLineWidth) {
    int targetLine = dy ~/ EditorConstants.lineHeight;
    if (targetLine >= lines.length) {
      targetLine = lines.length - 1;
    }

    double x = dx;
    String lineText = lines[targetLine];
    int targetColumn = 0;
    double currentWidth = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth = measureLineWidth(lineText[i]);
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    cursor.line = targetLine;
    cursor.column = targetColumn;
    clearSelection();
    notifyListeners();
  }

  void handleDragStart(
      double dy, double dx, Function(String line) measureLineWidth) {
    handleTap(dy, dx, measureLineWidth);
    startSelection();
    notifyListeners();
  }

  void handleDragUpdate(
      double dy, double dx, Function(String line) measureLineWidth) {
    int targetLine = dy ~/ EditorConstants.lineHeight;
    if (targetLine >= lines.length) {
      targetLine = lines.length - 1;
    } else if (targetLine < 0) {
      targetLine = 0;
    }

    double x = dx + scrollState.horizontalOffset;
    String lineText = lines[targetLine];
    int targetColumn = 0;
    double currentWidth = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth = measureLineWidth(lineText[i]);
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    cursor.line = targetLine;
    cursor.column = targetColumn;
    updateSelection();
    notifyListeners();
  }

  void insertNewLine() {
    if (selection != null) {
      deleteSelection();
    }

    String currentLine = lines[cursor.line];
    String remainingText = currentLine.substring(cursor.column);
    String beforeCursor = currentLine.substring(0, cursor.column);

    // Calculate indentation of current line
    String indentation = '';
    for (int i = 0; i < currentLine.length; i++) {
      if (currentLine[i] == ' ') {
        indentation += ' ';
      } else {
        break;
      }
    }

    // Keep indentation for new line
    lines[cursor.line] = beforeCursor;
    lines.insert(cursor.line + 1, indentation + remainingText);

    cursor.line++;
    cursor.column = indentation.length;
    version++;
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    if (lineNumber < 0 || lineNumber >= lines.length) return;

    if (!extend) {
      // Select single line
      cursor.line = lineNumber;
      cursor.column = lines[lineNumber].length;
      anchorLine = lineNumber;
      anchorColumn = 0;
      selection = Selection(
          startLine: lineNumber,
          endLine: lineNumber,
          startColumn: 0,
          endColumn: lines[lineNumber].length);
    } else {
      // Extend selection to include target line
      if (selection == null) {
        startSelection();
      }

      cursor.line = lineNumber;
      cursor.column = lines[lineNumber].length;

      if (lineNumber < anchorLine!) {
        selection = Selection(
            startLine: lineNumber,
            endLine: anchorLine!,
            startColumn: 0,
            endColumn: lines[anchorLine!].length);
      } else {
        selection = Selection(
            startLine: anchorLine!,
            endLine: lineNumber,
            startColumn: 0,
            endColumn: lines[lineNumber].length);
      }
    }

    notifyListeners();
  }

  void moveCursorDown(bool isShiftPressed) {
    if (cursor.line < lines.length - 1) {
      if (selection == null && isShiftPressed) {
        startSelection();
      }

      cursor.line++;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorLeft(bool isShiftPressed) {
    if (selection == null && isShiftPressed) {
      startSelection();
    }

    if (cursor.column > 0) {
      cursor.column--;
    } else if (cursor.line > 0) {
      cursor.line--;
      cursor.column = lines[cursor.line].length;
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorRight(bool isShiftPressed) {
    if (selection == null && isShiftPressed) {
      startSelection();
    }

    if (cursor.column < lines[cursor.line].length) {
      cursor.column++;
    } else if (cursor.line < lines.length - 1) {
      cursor.line++;
      cursor.column = 0;
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    if (cursor.line > 0) {
      if (selection == null && isShiftPressed) {
        startSelection();
      }

      cursor.line--;
      cursor.column = cursor.column.clamp(0, lines[cursor.line].length);
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void updateVerticalScrollOffset(double offset) {
    scrollState.updateVerticalScrollOffset(offset);
    notifyListeners();
  }

  void updateHorizontalScrollOffset(double offset) {
    scrollState.updateHorizontalScrollOffset(offset);
    notifyListeners();
  }

  void openFile(String content) {
    // Split content into lines and update the editor state
    lines = content.split('\n');
    if (lines.isEmpty) {
      lines = [''];
    }

    // Reset cursor and selection
    cursor = Cursor(0, 0);
    clearSelection();

    // Reset scroll positions
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);
    resetGutterScroll();

    version++;
    notifyListeners();
  }
}
