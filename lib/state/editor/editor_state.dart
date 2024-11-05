import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorState extends ChangeNotifier {
  Cursor cursor = Cursor(0, 0);
  EditorScrollState scrollState = EditorScrollState();
  Selection? selection;
  final Buffer _buffer = Buffer();
  int? anchorLine;
  int? anchorColumn;
  VoidCallback resetGutterScroll;
  bool showCaret = true;
  CursorShape cursorShape = CursorShape.bar;
  String path = '';
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  EditorState({required this.resetGutterScroll, this.path = ''});

  void executeCommand(Command command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    Command command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    Command command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
    notifyListeners();
  }

  Buffer get buffer => _buffer;

  double getGutterWidth() {
    return math.max((_buffer.lineCount.toString().length * 10.0) + 40.0, 48.0);
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
    anchorLine = _buffer.lineCount - 1;
    anchorColumn = _buffer.getLineLength(_buffer.lineCount - 1);
    cursor.line = 0;
    cursor.column = 0;
    selection = Selection(
        startLine: 0,
        endLine: _buffer.lineCount - 1,
        startColumn: 0,
        endColumn: _buffer.getLineLength(_buffer.lineCount - 1));
    notifyListeners();
  }

  String getSelectedText() {
    if (selection == null) return '';
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line selection
      return _buffer
          .getLine(_selection.startLine)
          .substring(_selection.startColumn, _selection.endColumn);
    }

    // Multi-line selection
    StringBuffer result = StringBuffer();

    // First line
    result.write(_buffer
        .getLine(_selection.startLine)
        .substring(_selection.startColumn));
    result.write('\n');

    // Middle lines
    for (int i = _selection.startLine + 1; i < _selection.endLine; i++) {
      result.write(_buffer.getLine(i));
      result.write('\n');
    }

    // Last line
    result.write(
        _buffer.getLine(_selection.endLine).substring(0, _selection.endColumn));

    return result.toString();
  }

  void deleteSelection() {
    if (selection == null) return;
    Selection _selection = selection!;

    if (_selection.startLine == _selection.endLine) {
      // Single line deletion
      String newContent = _buffer
              .getLine(_selection.startLine)
              .substring(0, _selection.startColumn) +
          _buffer.getLine(_selection.startLine).substring(_selection.endColumn);
      _buffer.setLine(_selection.startLine, newContent);
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    } else {
      // Multi-line deletion
      String startText = _buffer
          .getLine(_selection.startLine)
          .substring(0, _selection.startColumn);
      String endText =
          _buffer.getLine(_selection.endLine).substring(_selection.endColumn);

      // Combine first and last lines
      _buffer.setLine(_selection.startLine, startText + endText);

      // Remove lines in between
      for (int i = 0; i < _selection.endLine - _selection.startLine; i++) {
        _buffer.removeLine(_selection.startLine);
      }
      _buffer.setLine(_selection.startLine, '');

      // Update cursor position
      cursor.line = _selection.startLine;
      cursor.column = _selection.startColumn;
    }

    clearSelection();
    _buffer.incrementVersion();

    if (_buffer.isEmpty ||
        (_buffer.lineCount == 1 && _buffer.getLine(0).isEmpty)) {
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
      String currentLine = _buffer.getLine(cursor.line);
      String beforeCursor = currentLine.substring(0, cursor.column);
      if (beforeCursor.endsWith('    ') && beforeCursor.trim().isEmpty) {
        // Delete entire tab (4 spaces)
        _buffer.setLine(
            cursor.line,
            currentLine.substring(0, cursor.column - 4) +
                currentLine.substring(cursor.column));
        cursor.column -= 4;
      } else {
        // Normal single character deletion
        _buffer.setLine(
            cursor.line,
            currentLine.substring(0, cursor.column - 1) +
                currentLine.substring(cursor.column));
        cursor.column--;
      }
    } else if (cursor.line > 0) {
      cursor.column = _buffer.getLineLength(cursor.line - 1);
      _buffer.setLine(cursor.line - 1,
          _buffer.getLine(cursor.line - 1) + _buffer.getLine(cursor.line));
      _buffer.removeLine(cursor.line);
      cursor.line--;
    }
    _buffer.incrementVersion();
    notifyListeners();
  }

  void delete() {
    if (selection != null) {
      deleteSelection();
      return;
    }

    if (cursor.column < _buffer.getLineLength(cursor.line)) {
      String currentLine = _buffer.getLine(cursor.line);
      String afterCursor = currentLine.substring(cursor.column);
      if (afterCursor.startsWith('    ') &&
          afterCursor.substring(4).trim().isEmpty) {
        // Delete entire tab (4 spaces)
        _buffer.setLine(
            cursor.line,
            currentLine.substring(0, cursor.column) +
                currentLine.substring(cursor.column + 4));
      } else {
        // Normal single character deletion
        _buffer.setLine(
            cursor.line,
            currentLine.substring(0, cursor.column) +
                currentLine.substring(cursor.column + 1));
      }
    } else if (cursor.line < _buffer.lineCount - 1) {
      _buffer.setLine(cursor.line,
          _buffer.getLine(cursor.line) + _buffer.getLine(cursor.line + 1));
      _buffer.removeLine(cursor.line + 1);
    }
    _buffer.incrementVersion();
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
      String newContent =
          _buffer.getLine(cursor.line).substring(0, cursor.column) +
              pastedLines[0] +
              _buffer.getLine(cursor.line).substring(cursor.column);
      _buffer.setLine(cursor.line, newContent);
      cursor.column += pastedLines[0].length;
    } else {
      // Multi-line paste
      String remainingText =
          _buffer.getLine(cursor.line).substring(cursor.column);

      // First line
      _buffer.setLine(
          cursor.line,
          _buffer.getLine(cursor.line).substring(0, cursor.column) +
              pastedLines[0]);

      // Middle lines
      for (int i = 1; i < pastedLines.length - 1; i++) {
        _buffer.insertLine(cursor.line + i, content: pastedLines[i]);
      }

      // Last line
      _buffer.insertLine(cursor.line + pastedLines.length - 1,
          content: pastedLines.last + remainingText);

      cursor.line += pastedLines.length - 1;
      cursor.column = pastedLines.last.length;
    }

    _buffer.incrementVersion();
    notifyListeners();
  }

  void insertTab() {
    if (selection != null) {
      Selection _selection = selection!;

      // Add tab to each line in selection
      for (int i = _selection.startLine; i <= _selection.endLine; i++) {
        _buffer.setLine(i, '    ${_buffer.getLine(i)}');

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

    _buffer.incrementVersion();
    notifyListeners();
  }

  void backTab() {
    if (selection != null) {
      Selection _selection = selection!;

      // Remove tab from each line in selection
      for (int i = _selection.startLine; i <= _selection.endLine; i++) {
        if (_buffer.getLine(i).startsWith('    ')) {
          _buffer.setLine(i, _buffer.getLine(i).substring(4));

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
      String currentLine = _buffer.getLine(cursor.line);
      if (currentLine.startsWith('    ')) {
        _buffer.setLine(cursor.line, currentLine.substring(4));
        cursor.column = math.max(0, cursor.column - 4);
      }
    }

    _buffer.incrementVersion();
    notifyListeners();
  }

  void insertChar(String c) {
    if (selection != null) {
      deleteSelection();
    }

    executeCommand(
        TextInsertCommand(_buffer, c, cursor.line, cursor.column, cursor));
  }

  bool handleSpecialKeys(
      bool isControlPressed, bool isShiftPressed, LogicalKeyboardKey key) {
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
          String content = _buffer.lines.join('\n');
          FileService.saveFile(path, content);
          _buffer.setOriginalContent(content);
          notifyListeners();
          return true;
        }
      case LogicalKeyboardKey.keyZ:
        if (isControlPressed && isShiftPressed) {
          redo();
          return true;
        }

        if (isControlPressed) {
          undo();
          return true;
        }
    }

    return false;
  }

  void handleTap(double dy, double dx, Function(String line) measureLineWidth) {
    int targetLine = dy ~/ EditorConstants.lineHeight;
    if (targetLine >= _buffer.lineCount) {
      targetLine = _buffer.lineCount - 1;
    }

    double x = dx;
    String lineText = _buffer.getLine(targetLine);
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
    if (targetLine >= _buffer.lineCount) {
      targetLine = _buffer.lineCount - 1;
    } else if (targetLine < 0) {
      targetLine = 0;
    }

    double x = dx + scrollState.horizontalOffset;
    String lineText = _buffer.getLine(targetLine);
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

    String currentLine = _buffer.getLine(cursor.line);
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
    _buffer.setLine(cursor.line, beforeCursor);
    _buffer.insertLine(cursor.line + 1, content: indentation + remainingText);

    cursor.line++;
    cursor.column = indentation.length;
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    if (lineNumber < 0 || lineNumber >= _buffer.lineCount) return;

    if (!extend) {
      // Select single line
      cursor.line = lineNumber;
      cursor.column = _buffer.getLineLength(lineNumber);
      anchorLine = lineNumber;
      anchorColumn = 0;
      selection = Selection(
          startLine: lineNumber,
          endLine: lineNumber,
          startColumn: 0,
          endColumn: _buffer.getLineLength(lineNumber));
    } else {
      // Extend selection to include target line
      if (selection == null) {
        startSelection();
      }

      cursor.line = lineNumber;
      cursor.column = _buffer.getLineLength(lineNumber);

      if (lineNumber < anchorLine!) {
        selection = Selection(
            startLine: lineNumber,
            endLine: anchorLine!,
            startColumn: 0,
            endColumn: _buffer.getLineLength(anchorLine!));
      } else {
        selection = Selection(
            startLine: anchorLine!,
            endLine: lineNumber,
            startColumn: 0,
            endColumn: _buffer.getLineLength(lineNumber));
      }
    }

    notifyListeners();
  }

  void moveCursorDown(bool isShiftPressed) {
    if (cursor.line < _buffer.lineCount - 1) {
      if (selection == null && isShiftPressed) {
        startSelection();
      }

      cursor.line++;
      cursor.column =
          cursor.column.clamp(0, _buffer.getLineLength(cursor.line));
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
      cursor.column = _buffer.getLineLength(cursor.line);
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

    if (cursor.column < _buffer.getLineLength(cursor.line)) {
      cursor.column++;
    } else if (cursor.line < _buffer.lineCount - 1) {
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
      cursor.column =
          cursor.column.clamp(0, _buffer.getLineLength(cursor.line));
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
    // Reset cursor and selection
    cursor = Cursor(0, 0);
    clearSelection();
    _buffer.setContent(content);

    // Reset scroll positions
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);
    resetGutterScroll();

    notifyListeners();
  }
}
