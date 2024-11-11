import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class EditorState extends ChangeNotifier {
  final String id = UniqueKey().toString();
  EditorScrollState scrollState = EditorScrollState();
  final Buffer _buffer = Buffer();
  int? anchorLine;
  int? anchorColumn;
  VoidCallback resetGutterScroll;
  bool showCaret = true;
  CursorShape cursorShape = CursorShape.bar;
  String path = '';
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final EditorCursorManager editorCursorManager = EditorCursorManager();
  final EditorSelectionManager editorSelectionManager =
      EditorSelectionManager();
  final Future<void> Function(String) tapCallback;
  bool isPinned = false;
  String? relativePath = '';

  EditorState({
    required this.resetGutterScroll,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.tapCallback,
    String? path,
    this.relativePath,
  }) : path = path ?? generateUniqueTempPath();

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

  void toggleCaret() {
    showCaret = !showCaret;
    notifyListeners();
  }

  void startSelection() {
    editorSelectionManager.startSelection(editorCursorManager.cursors);
  }

  void updateSelection() {
    editorSelectionManager.updateSelection(editorCursorManager.cursors);
  }

  void clearSelection() {
    editorSelectionManager.clearAll();
    notifyListeners();
  }

  /// Clear all selections and add a single selection that encompasses the whole document.
  ///
  /// Creates a new [Selection] that spans from the start (0,0) to the last character
  /// of the last line in the document. Updates the [EditorSelectionManager] with this
  /// new selection and notifies listeners of the change.
  void selectAll() {
    editorSelectionManager.selectAll(
        _buffer.lineCount - 1, _buffer.getLineLength(_buffer.lineCount - 1));
    notifyListeners();
  }

  String getSelectedText() {
    return editorSelectionManager.getSelectedText(_buffer);
  }

  void deleteSelection() {
    if (!editorSelectionManager.hasSelection()) return;

    var newStartLinesColumns = editorSelectionManager.deleteSelection(_buffer);

    // Update cursor positions
    editorCursorManager.setAllCursors(newStartLinesColumns);
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
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    editorCursorManager.backspace(_buffer);
    _buffer.incrementVersion();
    notifyListeners();
  }

  void delete() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    editorCursorManager.delete(buffer);
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

    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
    }

    String pastedLines = data.text!;
    editorCursorManager.paste(_buffer, pastedLines);

    _buffer.incrementVersion();
    notifyListeners();
  }

  void insertTab() {
    if (editorSelectionManager.hasSelection()) {
      var newCursors = editorSelectionManager.insertTab(
          _buffer, editorCursorManager.cursors);
      editorCursorManager.setAllCursors(newCursors);
    } else {
      // Insert tab at cursor position
      insertChar('    ');
    }

    _buffer.incrementVersion();
    notifyListeners();
  }

  void backTab() {
    if (editorSelectionManager.hasSelection()) {
      var newCursors =
          editorSelectionManager.backTab(buffer, editorCursorManager.cursors);
      editorCursorManager.setAllCursors(newCursors);
    } else {
      editorCursorManager.backTab(_buffer);
    }

    _buffer.incrementVersion();
    notifyListeners();
  }

  void insertChar(String c) {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
    }

    var sortedCursors = List.from(editorCursorManager.cursors)
      ..sort((a, b) {
        if (a.line != b.line) {
          return a.line.compareTo(b.line);
        }
        return a.column.compareTo(b.column);
      });

    // Keep track of adjustments needed for subsequent cursors
    for (int i = 0; i < sortedCursors.length; i++) {
      var currentCursor = sortedCursors[i];

      // Apply adjustments to later cursors if they're on the same line
      if (i < sortedCursors.length - 1) {
        for (int j = i + 1; j < sortedCursors.length; j++) {
          var laterCursor = sortedCursors[j];

          if (laterCursor.line == currentCursor.line &&
              laterCursor.column > currentCursor.column) {
            // Adjust the column position for cursors after the insertion point
            laterCursor.column += c.length;
          }
        }
      }

      executeCommand(TextInsertCommand(
          _buffer, c, currentCursor.line, currentCursor.column, currentCursor));
    }
  }

  bool handleSpecialKeys(
      bool isControlPressed, bool isShiftPressed, LogicalKeyboardKey key) {
    switch (key) {
      case LogicalKeyboardKey.add:
        if (isControlPressed) {
          editorConfigService.config.fontSize += 2.0;
          editorLayoutService.updateFontSize(
              editorConfigService.config.fontSize,
              editorConfigService.config.fontFamily);
          editorLayoutService.config.lineHeight =
              editorConfigService.config.fontSize *
                  editorLayoutService.config.lineHeightMultiplier;
          editorConfigService.saveConfig();
          notifyListeners();
          return true;
        }
      case LogicalKeyboardKey.minus:
        if (isControlPressed) {
          if (editorConfigService.config.fontSize > 8.0) {
            editorConfigService.config.fontSize -= 2.0;
            editorLayoutService.updateFontSize(
                editorConfigService.config.fontSize,
                editorConfigService.config.fontFamily);

            editorLayoutService.config.lineHeight =
                editorConfigService.config.fontSize *
                    editorLayoutService.config.lineHeightMultiplier;

            editorConfigService.saveConfig();
            notifyListeners();
          }
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

  Future<bool> _writeFileToDisk(String path, String content) async {
    try {
      FileService.saveFile(path, content);
      _buffer.setOriginalContent(content);
      notifyListeners();
      return true;
    } catch (e) {
      // Handle error
      return false;
    }
  }

  Future<bool> saveFile(String path) async {
    if (path.isEmpty || path.startsWith('__temp')) {
      return saveFileAs(path);
    }

    final String content = _buffer.lines.join('\n');
    return _writeFileToDisk(path, content);
  }

  Future<bool> saveFileAs(String path) async {
    try {
      final String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Save As',
          fileName: p.basename(path).contains('__temp') ? '' : p.basename(path),
          initialDirectory: p.dirname(path));

      if (outputFile == null) {
        return false; // User cancelled
      }

      final String content = _buffer.lines.join('\n');
      return _writeFileToDisk(outputFile, content);
    } catch (e) {
      return false;
    }
  }

  void handleTap(double dy, double dx, Function(String line) measureLineWidth,
      bool isAltPressed) {
    int targetLine = dy ~/ editorLayoutService.config.lineHeight;
    if (targetLine >= _buffer.lineCount) {
      targetLine = _buffer.lineCount - 1;
    }

    double x = dx;
    String lineText = _buffer.getLine(targetLine);
    int targetColumn = 0;
    double currentWidth = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth =
          editorLayoutService.config.charWidth * lineText[i].length;
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    // Single cursor
    if (!isAltPressed) {
      editorCursorManager.clearAll();
      editorCursorManager.addCursor(Cursor(targetLine, targetColumn));
      clearSelection();
    } else {
      // Multi cursor
      // Check if overlapping -- if so, remove cursor
      // if it is not the last one
      if (editorCursorManager.cursorExistsAtPosition(
          targetLine, targetColumn)) {
        if (editorCursorManager.cursors.length > 1) {
          editorCursorManager.removeCursor(Cursor(targetLine, targetColumn));
        }
      } else {
        editorCursorManager.addCursor(Cursor(targetLine, targetColumn));
      }
      // TODO add more refined logic for multi cursor selection -- check if tap is within selection, etc.
      clearSelection();
    }
    notifyListeners();
  }

  List<Selection> getCurrentSelections() {
    return editorSelectionManager.selections.toList();
  }

  void restoreSelections(List<Selection> selections) {
    editorSelectionManager.clearAll();
    for (var selection in selections) {
      editorSelectionManager.addSelection(selection);
    }
    notifyListeners();
  }

  void handleDragStart(double dy, double dx,
      Function(String line) measureLineWidth, bool isAltPressed) {
    handleTap(dy, dx, measureLineWidth, isAltPressed);
    startSelection();
    notifyListeners();
  }

  void handleDragUpdate(
      double dy, double dx, Function(String line) measureLineWidth) {
    int targetLine = dy ~/ editorLayoutService.config.lineHeight;
    if (targetLine >= _buffer.lineCount) {
      targetLine = _buffer.lineCount - 1;
    } else if (targetLine < 0) {
      targetLine = 0;
    }

    double x = dx;
    String lineText = _buffer.getLine(targetLine);
    int targetColumn = 0;
    double currentWidth = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth =
          editorLayoutService.config.charWidth * lineText[i].length;
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    // Clear and set single cursor
    editorCursorManager.clearAll();
    editorCursorManager.addCursor(Cursor(targetLine, targetColumn));
    updateSelection();
    notifyListeners();
  }

  void insertNewLine() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
    }

    editorCursorManager.insertNewLine(_buffer);
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    if (lineNumber < 0 || lineNumber >= _buffer.lineCount) return;

    editorSelectionManager.selectLine(buffer, extend, lineNumber);
    editorCursorManager.clearAll();
    editorCursorManager
        .addCursor(Cursor(lineNumber, _buffer.getLineLength(lineNumber)));

    notifyListeners();
  }

  void moveCursorDown(bool isShiftPressed) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    editorCursorManager.moveDown(_buffer);

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorLeft(bool isShiftPressed) {
    // TODO revise this?
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    editorCursorManager.moveLeft(_buffer);

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorRight(bool isShiftPressed) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    editorCursorManager.moveRight(_buffer);

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }

    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    editorCursorManager.moveUp(_buffer);

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
    editorCursorManager.reset();
    clearSelection();
    _buffer.setContent(content);

    // Reset scroll positions
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);
    resetGutterScroll();

    notifyListeners();
  }

  void requestFocus() {
    notifyListeners();
  }
}
