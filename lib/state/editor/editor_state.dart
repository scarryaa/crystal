import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/breadcrumb_generator.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/handlers/command_handler.dart';
import 'package:crystal/services/editor/handlers/cursor_movement_handler.dart';
import 'package:crystal/services/editor/handlers/folding_handler.dart';
import 'package:crystal/services/editor/handlers/input_handler.dart';
import 'package:crystal/services/editor/handlers/scroll_handler.dart';
import 'package:crystal/services/editor/handlers/selection_handler.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:crystal/widgets/editor/editor_control_bar_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorState extends ChangeNotifier {
  late final CommandHandler commandHandler;
  late final InputHandler inputHandler;
  late final TextManipulator textManipulator;
  late final CursorMovementHandler cursorMovementHandler;
  late final SelectionHandler selectionHandler;
  late final FoldingHandler foldingHandler;
  late final ScrollHandler scrollHandler;

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
  late final BreadcrumbGenerator _breadcrumbGenerator;
  List<BreadcrumbItem> _breadcrumbs = [];
  List<BreadcrumbItem> get breadcrumbs => _breadcrumbs;

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
    textManipulator = TextManipulator(
      editorSelectionManager: editorSelectionManager,
      editorCursorManager: editorCursorManager,
      buffer: buffer,
      foldingManager: foldingManager,
      undoRedoManager: undoRedoManager,
      notifyListeners: notifyListeners,
    );
    commandHandler = CommandHandler(
        undoRedoManager: undoRedoManager,
        editorSelectionManager: editorSelectionManager,
        editorCursorManager: editorCursorManager,
        textManipulator: textManipulator,
        buffer: buffer,
        notifyListeners: notifyListeners,
        getSelectedText: getSelectedText);
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
      undo: commandHandler.undo,
      redo: commandHandler.redo,
      onDirectoryChanged: onDirectoryChanged,
      fileService: fileService,
    );
    cursorMovementHandler = CursorMovementHandler(
      buffer: buffer,
      foldingManager: foldingManager,
      editorCursorManager: editorCursorManager,
      editorSelectionManager: editorSelectionManager,
      notifyListeners: notifyListeners,
      startSelection: startSelection,
      updateSelection: updateSelection,
      clearSelection: clearSelection,
    );
    scrollHandler = ScrollHandler(
      scrollState: scrollState,
      notifyListeners: notifyListeners,
    );
    foldingHandler = FoldingHandler(
        buffer: buffer,
        foldingManager: foldingManager,
        notifyListeners: notifyListeners);

    _breadcrumbGenerator = BreadcrumbGenerator();
    editorCursorManager.onCursorChange = _updateBreadcrumbs;
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
  void _updateBreadcrumbs(int line, int column) {
    String sourceCode = buffer.lines.join('\n');
    int cursorOffset = _calculateCursorOffset(sourceCode, line, column);

    _breadcrumbs =
        _breadcrumbGenerator.generateBreadcrumbs(sourceCode, cursorOffset);
    notifyListeners();
  }

  int _calculateCursorOffset(String sourceCode, int line, int column) {
    List<String> lines = sourceCode.split('\n');
    int offset = 0;
    for (int i = 0; i < line; i++) {
      offset += lines[i].length + 1; // +1 for newline character
    }
    return offset + column;
  }

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
  bool isLineHidden(int line) => foldingHandler.isLineHidden(line);
  bool isFoldable(int line) => foldingHandler.isFoldable(line);
  bool isLineFolded(int line) => foldingHandler.isLineFolded(line);
  void toggleFold(
    int startLine,
    int endLine, {
    Map<int, int>? nestedFolds,
  }) =>
      foldingHandler.toggleFold(startLine, endLine);

  // Buffer / Text manipulation
  void insertNewLine() => textManipulator.insertNewLine();
  void backspace() => textManipulator.backspace();
  void delete() => textManipulator.delete();
  void backTab() => textManipulator.backTab();
  void insertTab() => textManipulator.insertTab();
  void insertChar(String c) => textManipulator.insertChar(c);

  // Undo/redo management
  void paste() => commandHandler.paste();
  void copy() => commandHandler.copy();
  void cut() => commandHandler.cut();
  void undo() => commandHandler.undo();
  void redo() => commandHandler.redo();

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

  // SelectionManager methods

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

  // Cursor methods
  void moveCursorUp(bool isShiftPressed) =>
      cursorMovementHandler.moveCursorUp(isShiftPressed);
  void moveCursorDown(bool isShiftPressed) =>
      cursorMovementHandler.moveCursorDown(isShiftPressed);
  void moveCursorLeft(bool isShiftPressed) =>
      cursorMovementHandler.moveCursorLeft(isShiftPressed);
  void moveCursorRight(bool isShiftPressed) =>
      cursorMovementHandler.moveCursorRight(isShiftPressed);

  void toggleCaret() {
    editorCursorManager.toggleCaret();
    notifyListeners();
  }

  // Scroll methods
  void updateVerticalScrollOffset(double offset) =>
      scrollHandler.updateVerticalScrollOffset(offset);
  void updateHorizontalScrollOffset(double offset) =>
      scrollHandler.updateHorizontalScrollOffset(offset);

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
    _updateBreadcrumbs(0, 0);

    notifyListeners();
  }
}
