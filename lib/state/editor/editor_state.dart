import 'dart:async';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/completion_service.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/controllers/lsp_controller.dart';
import 'package:crystal/services/editor/controllers/selection_controller.dart';
import 'package:crystal/services/editor/controllers/text_controller.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_event_emitter.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/handlers/command_handler.dart';
import 'package:crystal/services/editor/handlers/completion_manager.dart';
import 'package:crystal/services/editor/handlers/folding_handler.dart';
import 'package:crystal/services/editor/handlers/input_handler.dart';
import 'package:crystal/services/editor/handlers/scroll_handler.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:crystal/state/editor/editor_core_state.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart' hide TextRange;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class EditorState extends ChangeNotifier {
  late final CursorController cursorController;
  late final TextController textController;
  late final SelectionController selectionController;
  late final LSPController lspController;

  late final EditorEventEmitter eventEmitter;
  late final EditorCoreState coreState;
  late final CommandHandler commandHandler;

  late final CompletionManager completionManager;
  late final InputHandler inputHandler;
  late final FoldingHandler foldingHandler;
  late final ScrollHandler scrollHandler;
  late Language? detectedLanguage;

  late FoldingManager foldingManager;
  EditorScrollState scrollState = EditorScrollState();
  final UndoRedoManager undoRedoManager = UndoRedoManager();
  final EditorLayoutService editorLayoutService;
  late final EditorFileManager editorFileManager;
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final Future<void> Function(String) tapCallback;
  bool isPinned = false;
  late final CompletionService _completionService;
  int selectedSuggestionIndex = 0;
  final List<EditorState> editors;
  final EditorTabManager editorTabManager;
  final GitService gitService;
  bool isHoverInfoVisible = false;

  EditorState({
    required VoidCallback resetGutterScroll,
    String? path,
    String? relativePath,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.onDirectoryChanged,
    required this.tapCallback,
    required this.fileService,
    required this.editors,
    required this.editorTabManager,
    required this.gitService,
  }) {
    final filename = path != null && path.isNotEmpty ? p.split(path).last : '';
    final buffer = Buffer();
    cursorController = CursorController(
      buffer: buffer,
      foldingManager: null,
      selectionController: null,
    );

    editorFileManager = EditorFileManager(buffer, fileService);
    selectionController = SelectionController(
        cursorController: cursorController,
        foldingManager: null,
        buffer: buffer,
        notifyListeners: notifyListeners,
        emitSelectionChangedEvent: null);
    eventEmitter = EditorEventEmitter(
      selectionController: selectionController,
      buffer: buffer,
      path: path!,
      relativePath: relativePath,
      getSelectedText: getSelectedText,
      gitService: gitService,
    );

    coreState = EditorCoreState(
        path: path,
        relativePath: relativePath,
        resetGutterScroll: resetGutterScroll,
        buffer: buffer,
        fileManager: editorFileManager,
        cursorController: cursorController,
        eventEmitter: eventEmitter);

    detectedLanguage =
        LanguageDetectionService.getLanguageFromFilename(filename);

    foldingManager = FoldingManager(buffer,
        useIndentationFolding: coreState.indentationBasedLanguages
            .contains(detectedLanguage?.toLowerCase));

    cursorController.foldingManager = foldingManager;
    cursorController.selectionController = selectionController;
    selectionController.foldingManager = foldingManager;
    selectionController.emitSelectionChangedEvent =
        eventEmitter.emitSelectionChangedEvent;

    detectedLanguage =
        LanguageDetectionService.getLanguageFromFilename(filename);

    _completionService = CompletionService(this);
    completionManager = CompletionManager(
      cursorController: cursorController,
      buffer: buffer,
      completionService: _completionService,
      notifyListeners: notifyListeners,
    );
    textController = TextController(
      buffer: buffer,
      selectionController: selectionController,
      cursorController: cursorController,
      foldingManager: foldingManager,
      undoRedoManager: undoRedoManager,
      onTextChanged: () => _emitTextChangedEvent(),
      updateCompletions: () => updateCompletions(),
      notifyListeners: () => notifyListeners(),
    );

    commandHandler = CommandHandler(
        undoRedoManager: undoRedoManager,
        selectionController: selectionController,
        cursorController: cursorController,
        textController: textController,
        buffer: buffer,
        notifyListeners: notifyListeners,
        getSelectedText: getSelectedText);
    inputHandler = InputHandler(
      buffer: buffer,
      editorLayoutService: editorLayoutService,
      editorConfigService: editorConfigService,
      cursorController: cursorController,
      selectionController: selectionController,
      foldingManager: foldingManager,
      notifyListeners: notifyListeners,
      undo: commandHandler.undo,
      redo: commandHandler.redo,
      onDirectoryChanged: onDirectoryChanged,
      fileService: fileService,
      path: path,
      editors: editors,
      splitHorizontally: editorTabManager.addHorizontalSplit,
      splitVertically: editorTabManager.addVerticalSplit,
    );
    scrollHandler = ScrollHandler(
      scrollState: scrollState,
      notifyListeners: notifyListeners,
    );
    foldingHandler = FoldingHandler(
        buffer: buffer,
        foldingManager: foldingManager,
        notifyListeners: notifyListeners);

    cursorController.onCursorChange = coreState.updateBreadcrumbs;
    lspController = LSPController(this);
    lspController.initialize();

    buffer.addListener(() async {
      await lspController.sendDidChangeNotification(buffer.content);
    });
    EditorEventBus.on<HoverEvent>().listen((event) {
      if (event.line >= 0 && event.character >= 0 && event.content.isNotEmpty) {
        isHoverInfoVisible = true;
      } else {
        isHoverInfoVisible = false;
      }
    });
  }

  // Getters
  List<lsp_models.Diagnostic> get diagnostics => lspController.diagnostics;
  String get path => coreState.path;
  String? get relativePath => coreState.relativePath;
  String get id => coreState.id;
  Future<void> save() => coreState.save();
  Future<bool> saveFile(String path) => coreState.saveFile(path);
  Future<bool> saveFileAs(String path) async => coreState.saveFileAs(path);
  bool get showCaret => cursorController.showCaret;
  CursorShape get cursorShape => cursorController.cursorShape;
  int get cursorLine => cursorController.getCursorLine();
  Map<int, int> get foldingRanges => foldingManager.foldingState.foldingRanges;
  Buffer get buffer => coreState.buffer;
  bool get showCompletions => completionManager.showCompletions;
  ValueNotifier<int> get selectedSuggestionIndexNotifier =>
      completionManager.selectedSuggestionIndexNotifier;
  List<CompletionItem> get suggestions => completionManager.suggestions;
  List<Cursor> get cursors => cursorController.cursors;
  List<Selection> get selections => selectionController.selections;

  // Setters
  set showCompletions(bool show) => completionManager.showCompletions = show;
  set showCaret(bool show) => cursorController.showCaret = show;
  set onCursorChange(Function(int, int)? changeFn) =>
      cursorController.onCursorChange = changeFn;

  void resetGutterScroll() => coreState.resetGutterScroll();
  void setCursor(int line, int col) => cursorController.setCursor(line, col);
  void setAllCursors(List<Cursor> cursors) =>
      cursorController.setAllCursors(cursors);
  void clearAllCursors() => cursorController.clearAll();
  void addCursor(int line, int col) => cursorController.addCursor(line, col);
  void moveCursor(int line, int col) => cursorController.moveCursor(line, col);
  void setAllSelections(List<Selection> newSelections) =>
      selectionController.setAllSelections(newSelections);
  void clearAllSelections() => selectionController.clearAll();
  void addSelection(Selection s) => selectionController.addSelection(s);

  // Events
  void _emitTextChangedEvent() {
    EditorEventBus.emit(TextEvent(
      content: buffer.toString(),
      isDirty: buffer.isDirty,
      path: coreState.path,
    ));

    if (coreState.path.isNotEmpty && !coreState.path.startsWith('__temp')) {
      gitService.updateDocumentChanges(
          coreState.relativePath ?? '', buffer.lines);
    }
    notifyListeners();
  }

  // LSP Methods
  void setIsHoveringPopup(bool isHovering) =>
      lspController.setIsHoveringPopup(isHovering);
  void updateDiagnostics(List<lsp_models.Diagnostic> newDiagnostics) =>
      lspController.updateDiagnostics(newDiagnostics);
  Future<void> showHover(int line, int character) =>
      lspController.showHover(line, character);
  Future<List<lsp_models.Diagnostic>?> showDiagnostics(int line, int col) =>
      lspController.showDiagnostics(line, col);
  String formatRustDiagnostics(List<lsp_models.Diagnostic> diagnostics) =>
      lspController.formatRustDiagnostics();
  String getSeverityLabel(lsp_models.DiagnosticSeverity severity) =>
      lspController.getSeverityLabel(severity);
  Future<void> goToDefinition(int line, int character) async =>
      lspController.goToDefinition(line, character);

  void scrollToLine(int line) {
    const lineHeight = 20.0;
    updateVerticalScrollOffset(line * lineHeight);
  }

  // Completions
  void selectNextSuggestion() => completionManager.selectNextSuggestion();
  void selectPreviousSuggestion() =>
      completionManager.selectPreviousSuggestion();
  void resetSuggestionSelection() =>
      completionManager.resetSuggestionSelection();
  void updateCompletions() => completionManager.updateCompletions();
  void acceptCompletion(CompletionItem item) =>
      completionManager.acceptCompletion(item);

  // Misc
  List<TextRange> findAllOccurrences(String word) {
    List<TextRange> occurrences = [];
    for (int i = 0; i < buffer.lines.length; i++) {
      String line = buffer.lines[i];
      int index = 0;
      while (true) {
        index = line.indexOf(word, index);
        if (index == -1) break;

        // Check if it's a whole word match
        bool isWholeWord = true;
        if (index > 0 && _isWordChar(line[index - 1])) {
          isWholeWord = false;
        }
        if (index + word.length < line.length &&
            _isWordChar(line[index + word.length])) {
          isWholeWord = false;
        }

        if (isWholeWord) {
          occurrences.add(TextRange(
            start: Position(line: i, column: index),
            end: Position(line: i, column: index + word.length),
          ));
        }
        index += word.length;
      }
    }
    return occurrences;
  }

  bool _isWordChar(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  TextRange? getWordRangeAt(int line, int column) {
    if (line < 0 || line >= buffer.lines.length) return null;
    String lineText = buffer.lines[line];
    if (column < 0 || column >= lineText.length) return null;

    int start = column;
    int end = column;

    // Move start to the beginning of the word
    while (start > 0 && _isWordChar(lineText[start - 1])) {
      start--;
    }

    // Move end to the end of the word
    while (end < lineText.length && _isWordChar(lineText[end])) {
      end++;
    }

    // If we're not on a word character, return null
    if (start == end) return null;

    return TextRange(
      start: Position(line: line, column: start),
      end: Position(line: line, column: end),
    );
  }

  String getWordAt(int line, int column) {
    // Check if line is valid
    if (line < 0 || line >= buffer.lines.length) return '';

    final lineText = buffer.lines[line];

    // Check if column is valid
    if (column < 0 || column >= lineText.length) return '';

    // Find word boundaries
    int start = column;
    int end = column;

    while (start > 0 && _isWordChar(lineText[start - 1])) {
      start--;
    }

    while (end < lineText.length && _isWordChar(lineText[end])) {
      end++;
    }

    return lineText.substring(start, end);
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
    if (selectionController.hasSelection()) {
      return false;
    }

    for (var cursor in cursorController.cursors) {
      // Check if cursor is at start of line (for delete)
      // or end of line (for backspace)
      if ((cursor.column == 0 && cursor.line > 0) ||
          (cursor.column == coreState.buffer.getLineLength(cursor.line) &&
              cursor.line < coreState.buffer.lineCount - 1)) {
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
  void insertNewLine() => textController.insertNewLine();
  void backspace() => textController.backspace();
  void delete() => textController.delete();
  void backTab() => textController.backTab();
  void insertTab() => textController.insertTab();
  void insertChar(String c) => textController.insertChar(c);

  // Undo/redo management
  void copy() {
    commandHandler.copy();
    eventEmitter.emitClipboardEvent(getSelectedText(), ClipboardAction.copy);
  }

  void cut() {
    final textBeforeCut = getSelectedText();
    commandHandler.cut();
    updateCompletions();
    _emitTextChangedEvent();
    eventEmitter.emitClipboardEvent(textBeforeCut, ClipboardAction.cut);
  }

  void paste() {
    commandHandler.paste();
    updateCompletions();
    _emitTextChangedEvent();
    eventEmitter.emitClipboardEvent(getSelectedText(), ClipboardAction.paste);
  }

  void undo() {
    commandHandler.undo();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void redo() {
    commandHandler.redo();
    updateCompletions();
    _emitTextChangedEvent();
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

  // Selection methods
  void selectAll() => selectionController.selectAll();
  void selectLine(bool extend, int lineNumber) =>
      selectionController.selectLine(buffer, extend, lineNumber);
  void startSelection() => selectionController.startSelection(cursors);
  bool hasSelection() => selectionController.hasSelection();
  TextRange getSelectedLineRange() =>
      selectionController.getSelectedLineRange();
  String getSelectedText() => selectionController.getSelectedText();
  void updateSelection() => selectionController.updateSelection();
  void clearSelection() => selectionController.clearAll();

  // Cursor methods
  void moveCursorToLineStart(bool isShiftPressed) =>
      cursorController.moveCursorToLineStart(isShiftPressed);
  void moveCursorToLineEnd(bool isShiftPressed) =>
      cursorController.moveCursorToLineEnd(isShiftPressed);
  void moveCursorToDocumentStart(bool isShiftPressed) =>
      cursorController.moveCursorToDocumentStart(isShiftPressed);
  void moveCursorToDocumentEnd(bool isShiftPressed) =>
      cursorController.moveCursorToDocumentEnd(isShiftPressed);
  void moveCursorPageUp(bool isShiftPressed) =>
      cursorController.moveCursorPageUp(isShiftPressed);
  void moveCursorPageDown(bool isShiftPressed) =>
      cursorController.moveCursorPageDown(isShiftPressed);
  void moveCursorUp(bool isShiftPressed) =>
      cursorController.moveCursorUp(isShiftPressed);
  void moveCursorDown(bool isShiftPressed) =>
      cursorController.moveCursorDown(isShiftPressed);
  void moveCursorLeft(bool isShiftPressed) =>
      cursorController.moveCursorLeft(isShiftPressed);
  void moveCursorRight(bool isShiftPressed) =>
      cursorController.moveCursorRight(isShiftPressed);
  void toggleCaret() => cursorController.toggleCaret();

  // Scroll methods
  void updateVerticalScrollOffset(double offset) =>
      scrollHandler.updateVerticalScrollOffset(offset);
  void updateHorizontalScrollOffset(double offset) =>
      scrollHandler.updateHorizontalScrollOffset(offset);

  bool get isEmpty => buffer.isEmpty;

  void openFile(String content) {
    clearSelection();
    coreState.openFile(content);
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);

    notifyListeners();
  }
}
