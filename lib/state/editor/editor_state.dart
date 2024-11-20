import 'dart:async';

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
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_event_emitter.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/handlers/command_handler.dart';
import 'package:crystal/services/editor/handlers/completion_handler.dart';
import 'package:crystal/services/editor/handlers/cursor_movement_handler.dart';
import 'package:crystal/services/editor/handlers/folding_handler.dart';
import 'package:crystal/services/editor/handlers/input_handler.dart';
import 'package:crystal/services/editor/handlers/lsp_manager.dart';
import 'package:crystal/services/editor/handlers/scroll_handler.dart';
import 'package:crystal/services/editor/handlers/selection_handler.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:crystal/services/lsp_service.dart';
import 'package:crystal/state/editor/editor_core_state.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:flutter/material.dart' hide TextRange;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

class EditorState extends ChangeNotifier {
  late final EditorEventEmitter eventEmitter;
  late final EditorCoreState coreState;
  late final CommandHandler commandHandler;

  late final LSPManager lspManager;
  late final CompletionManager completionManager;
  late final InputHandler inputHandler;
  late final TextManipulator textManipulator;
  late final CursorMovementHandler cursorMovementHandler;
  late final SelectionHandler selectionHandler;
  late final FoldingHandler foldingHandler;
  late final ScrollHandler scrollHandler;
  late Language? detectedLanguage;

  late FoldingManager foldingManager;
  EditorScrollState scrollState = EditorScrollState();
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
  late final CompletionService _completionService;
  int selectedSuggestionIndex = 0;
  final List<EditorState> editors;
  final EditorTabManager editorTabManager;
  final GitService gitService;
  late final LSPService lspService;
  bool isHoverInfoVisible = false;
  List<lsp_models.Diagnostic> get diagnostics => lspManager.diagnostics;

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
    editorFileManager = EditorFileManager(buffer, fileService);

    eventEmitter = EditorEventEmitter(
      selectionManager: editorSelectionManager,
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
        cursorManager: editorCursorManager,
        eventEmitter: eventEmitter);

    detectedLanguage =
        LanguageDetectionService.getLanguageFromFilename(filename);

    _completionService = CompletionService(this);
    completionManager = CompletionManager(
      editorCursorManager: editorCursorManager,
      buffer: buffer,
      completionService: _completionService,
      notifyListeners: notifyListeners,
    );

    foldingManager = FoldingManager(
      coreState.buffer,
      useIndentationFolding: coreState.indentationBasedLanguages
          .contains(detectedLanguage?.toLowerCase),
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
      path: path,
      editors: editors,
      splitHorizontally: editorTabManager.addHorizontalSplit,
      splitVertically: editorTabManager.addVerticalSplit,
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

    editorCursorManager.onCursorChange = coreState.updateBreadcrumbs;
    lspService = LSPService(this);
    lspService.initialize();
    lspManager = LSPManager(
        buffer: buffer,
        setCursor: editorCursorManager.setCursor,
        lspService: lspService,
        tapCallback: tapCallback,
        scrollToLine: scrollToLine,
        notifyListeners: notifyListeners);

    buffer.addListener(() async {
      await lspService.sendDidChangeNotification(buffer.content);
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
  void resetGutterScroll() => coreState.resetGutterScroll();
  String get path => coreState.path;
  String? get relativePath => coreState.relativePath;
  String get id => coreState.id;
  Future<void> save() => coreState.save();
  Future<bool> saveFile(String path) => coreState.saveFile(path);
  Future<bool> saveFileAs(String path) async => coreState.saveFileAs(path);
  bool get showCaret => editorCursorManager.showCaret;
  CursorShape get cursorShape => editorCursorManager.cursorShape;
  int get cursorLine => editorCursorManager.getCursorLine();
  Map<int, int> get foldingRanges => foldingManager.foldingState.foldingRanges;
  Buffer get buffer => coreState.buffer;
  bool get showCompletions => completionManager.showCompletions;
  ValueNotifier<int> get selectedSuggestionIndexNotifier =>
      completionManager.selectedSuggestionIndexNotifier;
  List<CompletionItem> get suggestions => completionManager.suggestions;

  // Setters
  set showCompletions(bool show) => completionManager.showCompletions = show;
  set showCaret(bool show) => editorCursorManager.showCaret = show;

  // Events
  void _emitCursorChangedEvent() {
    EditorEventBus.emit(CursorEvent(
      cursors: editorCursorManager.cursors,
      line: editorCursorManager.getCursorLine(),
      column: editorCursorManager.cursors.isNotEmpty
          ? editorCursorManager.cursors.first.column
          : 0,
      hasSelection: editorSelectionManager.hasSelection(),
      selections: editorSelectionManager.selections,
    ));
  }

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
  }

  // LSP Methods
  void setIsHoveringPopup(bool isHovering) =>
      lspManager.setIsHoveringPopup(isHovering);
  void updateDiagnostics(List<lsp_models.Diagnostic> newDiagnostics) =>
      lspManager.updateDiagnostics(newDiagnostics);
  Future<void> showHover(int line, int character) =>
      lspManager.showHover(line, character);
  Future<List<lsp_models.Diagnostic>?> showDiagnostics(int line, int col) =>
      lspManager.showDiagnostics(line, col);

  String formatRustDiagnostics(List<lsp_models.Diagnostic> diagnostics) =>
      lspManager.formatRustDiagnostics(diagnostics);
  String getSeverityLabel(lsp_models.DiagnosticSeverity severity) =>
      lspManager.getSeverityLabel(severity);
  Future<void> goToDefinition(int line, int character) async {
    final response = await lspService.getDefinition(line, character);
    if (response != null) {
      final location = response['uri'];
      if (location != null) {
        // Remove the file:// prefix
        final path = location.toString().replaceFirst('file://', '');
        await tapCallback(path);

        // Jump to the definition location if provided
        if (response['range'] != null) {
          final targetLine = response['range']['start']['line'];
          final targetCharacter = response['range']['start']['character'];
          editorCursorManager.setCursor(targetLine, targetCharacter);
          scrollToLine(targetLine);
        }
      }
    }
  }

  void scrollToLine(int line) {
    // Assuming a fixed line height of 20 pixels
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

  void restoreSelections(List<Selection> selections) {
    editorSelectionManager.clearAll();
    for (var selection in selections) {
      editorSelectionManager.addSelection(selection);
    }
    eventEmitter.emitSelectionChangedEvent();

    notifyListeners();
  }

  void updateSelection() {
    editorSelectionManager.updateSelection(editorCursorManager.cursors);
    eventEmitter.emitSelectionChangedEvent();

    notifyListeners();
  }

  void clearSelection() {
    editorSelectionManager.clearAll();
    notifyListeners();
    eventEmitter.emitSelectionChangedEvent();
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
  void insertNewLine() {
    textManipulator.insertNewLine();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void backspace() {
    textManipulator.backspace();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void delete() {
    textManipulator.delete();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void backTab() {
    textManipulator.backTab();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void insertTab() {
    textManipulator.insertTab();
    updateCompletions();
    _emitTextChangedEvent();
  }

  void insertChar(String c) {
    textManipulator.insertChar(c);
    updateCompletions();
    _emitTextChangedEvent();
  }

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

  // SelectionManager methods

  /// Clear all selections and add a single selection that encompasses the whole document.
  ///
  /// Creates a new [Selection] that spans from the start (0,0) to the last character
  /// of the last line in the document. Updates the [EditorSelectionManager] with this
  /// new selection and notifies listeners of the change.

  void selectAll() {
    selectionHandler.selectAll();
    eventEmitter.emitSelectionChangedEvent();
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    selectionHandler.selectLine(extend, lineNumber);
    eventEmitter.emitSelectionChangedEvent();
    notifyListeners();
  }

  void startSelection() {
    selectionHandler.startSelection();
    eventEmitter.emitSelectionChangedEvent();
    notifyListeners();
  }

  bool hasSelection() => selectionHandler.hasSelection();
  TextRange getSelectedLineRange() => selectionHandler.getSelectedLineRange();

  String getSelectedText() {
    return editorSelectionManager.getSelectedText(coreState.buffer);
  }

  // Cursor methods
  void moveCursorToLineStart(bool isShiftPressed) {
    cursorMovementHandler.moveCursorToLineStart(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorToLineEnd(bool isShiftPressed) {
    cursorMovementHandler.moveCursorToLineEnd(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorToDocumentStart(bool isShiftPressed) {
    cursorMovementHandler.moveCursorToDocumentStart(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorToDocumentEnd(bool isShiftPressed) {
    cursorMovementHandler.moveCursorToDocumentEnd(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorPageUp(bool isShiftPressed) {
    cursorMovementHandler.moveCursorPageUp(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorPageDown(bool isShiftPressed) {
    cursorMovementHandler.moveCursorPageDown(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorUp(bool isShiftPressed) {
    cursorMovementHandler.moveCursorUp(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorDown(bool isShiftPressed) {
    cursorMovementHandler.moveCursorDown(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorLeft(bool isShiftPressed) {
    cursorMovementHandler.moveCursorLeft(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void moveCursorRight(bool isShiftPressed) {
    cursorMovementHandler.moveCursorRight(isShiftPressed);
    _emitCursorChangedEvent();
  }

  void toggleCaret() {
    editorCursorManager.toggleCaret();
    notifyListeners();
  }

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
