import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/handlers/input_handler.dart';
import 'package:crystal/services/editor/handlers/selection_handler.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Text buffer management
// Cursor management
// Selection management
// Folding management
// Undo/Redo functionality
// File operations
// Configuration management

// BufferManager
// CursorManager
// SelectionManager
// FoldingManager
// UndoRedoManager
// FileManager
// ConfigManager

class EditorState extends ChangeNotifier {
  // New structure?
  // final CommandHandler commandHandler;
  late final InputHandler inputHandler;
  late final TextManipulator textManipulator;
  // final CursorMovementHandler cursorMovementHandler;
  late final SelectionHandler selectionHandler;
  // final FoldingHandler foldingHandler;
  // final ScrollHandler scrollHandler;

  late final FoldingManager foldingManager;
  final String id = UniqueKey().toString();
  EditorScrollState scrollState = EditorScrollState();
  final Buffer _buffer = Buffer();
  VoidCallback resetGutterScroll;
  String path = '';
  final UndoRedoManager undoRedoManager = UndoRedoManager();
  final EditorLayoutService editorLayoutService;
  late final EditorFileManager editorFileManager;
  final EditorConfigService editorConfigService;
  final EditorCursorManager editorCursorManager = EditorCursorManager();
  final EditorSelectionManager editorSelectionManager =
      EditorSelectionManager();
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final Future<void> Function(String) tapCallback;
  bool isPinned = false;
  String? relativePath = '';

  EditorState({
    required this.resetGutterScroll,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.onDirectoryChanged,
    required this.tapCallback,
    required this.fileService,
    String? path,
    this.relativePath,
  }) : path = path ?? generateUniqueTempPath() {
    foldingManager = FoldingManager(
      _buffer,
    );
    editorFileManager = EditorFileManager(buffer, fileService);
    selectionHandler = SelectionHandler(
        selectionManager: editorSelectionManager,
        buffer: buffer,
        cursorManager: editorCursorManager,
        foldingManager: foldingManager);
    inputHandler = InputHandler(
      buffer: buffer,
      editorLayoutService: editorLayoutService,
      editorConfigService: editorConfigService,
      editorCursorManager: editorCursorManager,
      editorSelectionManager: editorSelectionManager,
      foldingManager: foldingManager,
      notifyListeners: notifyListeners,
      undo: undo,
      redo: redo,
      onDirectoryChanged: onDirectoryChanged,
      fileService: fileService,
    );
    textManipulator = TextManipulator(
      editorSelectionManager: editorSelectionManager,
      editorCursorManager: editorCursorManager,
      buffer: buffer,
      foldingManager: foldingManager,
      undoRedoManager: undoRedoManager,
      notifyListeners: notifyListeners,
    );
  }

  // Getters
  bool get showCaret => editorCursorManager.showCaret;
  CursorShape get cursorShape => editorCursorManager.cursorShape;
  int get cursorLine => editorCursorManager.getCursorLine();
  Map<int, int> get foldingRanges => foldingManager.foldingState.foldingRanges;
  Buffer get buffer => _buffer;

  // Setters
  set showCaret(bool show) => editorCursorManager.showCaret = show;

  // Misc
  int getLastPastedLineCount() {
    // Get the last command from undo stack
    if (!undoRedoManager.canUndo) {
      return 0;
    }

    Command lastCommand = undoRedoManager.getLastUndo();
    if (lastCommand is TextInsertCommand) {
      // Count newlines in inserted text
      return '\n'.allMatches(lastCommand.text).length + 1;
    }
    return 0;
  }

  bool isLineJoinOperation() {
    // Check if next delete/backspace will join lines
    if (editorSelectionManager.hasSelection()) {
      return false;
    }

    for (var cursor in editorCursorManager.cursors) {
      // Check if cursor is at start of line (for delete)
      // or end of line (for backspace)
      if ((cursor.column == 0 && cursor.line > 0) ||
          (cursor.column == _buffer.getLineLength(cursor.line) &&
              cursor.line < _buffer.lineCount - 1)) {
        return true;
      }
    }
    return false;
  }

  void requestFocus() {
    notifyListeners();
  }

  void recalculateVisibleLines() {
    notifyListeners();
  }

  // FoldingManager methods

  bool isLineHidden(int line) {
    return foldingManager.isLineHidden(line);
  }

  bool isLineFolded(int line) {
    return foldingManager.isLineFolded(line);
  }

  void toggleFold(int startLine, int endLine, {Map<int, int>? nestedFolds}) {
    // Check if the region is currently folded
    bool isFolded = buffer.foldedRanges.containsKey(startLine);

    if (isFolded) {
      // Unfold the region
      buffer.unfoldLines(startLine);
    } else {
      // Fold the region
      buffer.foldLines(startLine, endLine);
    }

    foldingManager.toggleFold(startLine, endLine);
    notifyListeners();
  }

  bool isFoldable(int line) {
    if (line >= buffer.lines.length) return false;

    final currentLine = buffer.lines[line].trim();
    if (currentLine.isEmpty) return false;

    // Check if line ends with block starter
    if (!currentLine.endsWith('{') &&
        !currentLine.endsWith('(') &&
        !currentLine.endsWith('[')) {
      return false;
    }

    final currentIndent = _getIndentation(buffer.lines[line]);

    // Look ahead for valid folding range
    int nextLine = line + 1;
    bool hasContent = false;

    while (nextLine < buffer.lines.length) {
      final nextLineText = buffer.lines[nextLine];
      if (nextLineText.trim().isEmpty) {
        nextLine++;
        continue;
      }

      final nextIndent = _getIndentation(nextLineText);
      if (nextIndent <= currentIndent) {
        return hasContent;
      }
      hasContent = true;
      nextLine++;
    }

    return false;
  }

  int _getIndentation(String line) {
    final match = RegExp(r'[^\s]').firstMatch(line);
    return match?.start ?? -1;
  }

  // Buffer / Text manipulation
  void insertNewLine() => textManipulator.insertNewLine();
  void backspace() => textManipulator.backspace();
  void delete() => textManipulator.delete();
  void backTab() => textManipulator.backTab();
  void insertTab() => textManipulator.insertTab();
  void insertChar(String c) => textManipulator.insertChar(c);

  // Undo/redo management
  bool get canUndo => undoRedoManager.canUndo;
  bool get canRedo => undoRedoManager.canRedo;

  void undo() {
    undoRedoManager.undo();
    notifyListeners();
  }

  void redo() {
    undoRedoManager.redo();
    notifyListeners();
  }

  // Input management
  void handleTap(double dy, double dx, Function(String) measureLineWidth,
          bool isAltPressed) =>
      inputHandler.handleTap(dy, dx, measureLineWidth, isAltPressed);
  void handleDragStart(double dy, double dx, Function(String) measureLineWidth,
          bool isAltPressed) =>
      inputHandler.handleDragStart(dy, dx, measureLineWidth, isAltPressed);
  void handleDragUpdate(
          double dy, double dx, Function(String) measureLineWidth) =>
      inputHandler.handleDragUpdate(dy, dx, measureLineWidth);
  Future<bool> handleSpecialKeys(
          bool isControlPressed, bool isShiftPressed, LogicalKeyboardKey key) =>
      inputHandler.handleSpecialKeys(isControlPressed, isShiftPressed, key);

  void cut() {
    copy();
    textManipulator.deleteSelection();
    notifyListeners();
  }

  void copy() {
    Clipboard.setData(ClipboardData(text: getSelectedText()));
  }

  Future<void> paste() async {
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null) return;

    if (editorSelectionManager.hasSelection()) {
      textManipulator.deleteSelection();
    }

    String pastedLines = data.text!;
    editorCursorManager.paste(_buffer, pastedLines);

    _buffer.incrementVersion();
    notifyListeners();
  }

  // SelectionManager methods
  void restoreSelections(List<Selection> selections) {
    editorSelectionManager.clearAll();
    for (var selection in selections) {
      editorSelectionManager.addSelection(selection);
    }
    notifyListeners();
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
    selectionHandler.selectAll();
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    selectionHandler.selectLine(extend, lineNumber);
    notifyListeners();
  }

  void startSelection() {
    selectionHandler.startSelection();
    notifyListeners();
  }

  bool hasSelection() => selectionHandler.hasSelection();
  TextRange getSelectedLineRange() => selectionHandler.getSelectedLineRange();

  String getSelectedText() {
    return editorSelectionManager.getSelectedText(_buffer);
  }

  // CursorManager methods
  void toggleCaret() {
    editorCursorManager.toggleCaret();
    notifyListeners();
  }

  void _moveCursor(
      bool isShiftPressed, void Function(Buffer, FoldingManager) moveFunction) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    moveFunction(buffer, foldingManager);

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorUp(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveUp);
  }

  void moveCursorDown(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveDown);
  }

  void moveCursorLeft(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveLeft);
  }

  void moveCursorRight(bool isShiftPressed) {
    _moveCursor(isShiftPressed, editorCursorManager.moveRight);
  }

  // Scroll methods
  void updateVerticalScrollOffset(double offset) {
    scrollState.updateVerticalScrollOffset(offset);
    notifyListeners();
  }

  void updateHorizontalScrollOffset(double offset) {
    scrollState.updateHorizontalScrollOffset(offset);
    notifyListeners();
  }

  // File management
  Future<bool> saveFile(path) => editorFileManager.saveFile(path);
  Future<bool> saveFileAs(path) => editorFileManager.saveFileAs(path);

  void openFile(String content) {
    // Reset cursor and selection
    editorCursorManager.reset();
    clearSelection();
    editorFileManager.openFile(content);

    // Reset scroll positions
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);
    resetGutterScroll();

    notifyListeners();
  }
}
