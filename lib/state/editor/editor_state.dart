import 'dart:async';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/breadcrumb_generator.dart';
import 'package:crystal/services/editor/completion_service.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
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
import 'package:crystal/services/git_service.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:crystal/services/lsp_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:flutter/material.dart' hide TextRange;
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

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
  late final CompletionService _completionService;
  List<CompletionItem> suggestions = [];
  bool showCompletions = false;
  int selectedSuggestionIndex = 0;
  final ValueNotifier<int> selectedSuggestionIndexNotifier = ValueNotifier(0);
  final List<EditorState> editors;
  final EditorTabManager editorTabManager;
  final GitService gitService;
  late final LSPService lspService;
  bool isHoverInfoVisible = false;
  Position? _lastHoverPosition;
  Timer? _hoverTimer;
  List<lsp_models.Diagnostic> _diagnostics = [];
  List<lsp_models.Diagnostic> get diagnostics => _diagnostics;
  bool _isHoveringPopup = false;
  String? _lastHoveredWord;

  EditorState({
    required this.resetGutterScroll,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.onDirectoryChanged,
    required this.tapCallback,
    required this.fileService,
    String? path,
    this.relativePath,
    required this.editors,
    required this.editorTabManager,
    required this.gitService,
  }) : path = path ?? generateUniqueTempPath() {
    final filename = path != null && path.isNotEmpty ? p.split(path).last : '';

    final detectedLanguage =
        LanguageDetectionService.getLanguageFromFilename(filename);
    const indentationBasedLanguages = {
      'python',
      'yaml',
      'yml',
      'pug',
      'sass',
      'haml',
      'markdown',
      'gherkin',
      'nim'
    };

    _completionService = CompletionService(this);

    foldingManager = FoldingManager(
      _buffer,
      useIndentationFolding:
          indentationBasedLanguages.contains(detectedLanguage.toLowerCase),
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
      path: path ?? '',
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

    _breadcrumbGenerator = BreadcrumbGenerator();
    editorCursorManager.onCursorChange = _updateBreadcrumbs;
    lspService = LSPService(this);

    buffer.addListener(() {
      lspService.sendDidChangeNotification(buffer.content);
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
  bool get showCaret => editorCursorManager.showCaret;
  CursorShape get cursorShape => editorCursorManager.cursorShape;
  int get cursorLine => editorCursorManager.getCursorLine();
  Map<int, int> get foldingRanges => foldingManager.foldingState.foldingRanges;
  Buffer get buffer => _buffer;

  // Setters
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
      path: path,
    ));

    if (path.isNotEmpty && !path.startsWith('__temp')) {
      gitService.updateDocumentChanges(relativePath ?? '', buffer.lines);
    }
  }

  void _emitSelectionChangedEvent() {
    EditorEventBus.emit(SelectionEvent(
      selections: editorSelectionManager.selections,
      hasSelection: editorSelectionManager.hasSelection(),
      selectedText: getSelectedText(),
    ));
  }

  void _emitFileChangedEvent() {
    EditorEventBus.emit(FileEvent(
      path: path,
      relativePath: relativePath,
      content: buffer.toString(),
      isDirty: buffer.isDirty,
    ));
  }

  void _emitClipboardEvent(String text, ClipboardAction action) {
    EditorEventBus.emit(ClipboardEvent(
      text: text,
      action: action,
    ));
  }

  void _emitErrorEvent(String message, [String? path, Object? error]) {
    EditorEventBus.emit(ErrorEvent(
      message: message,
      path: path,
      error: error,
    ));
  }

  // LSP Methods
  void setIsHoveringPopup(bool isHovering) {
    _isHoveringPopup = isHovering;
  }

  void updateDiagnostics(List<lsp_models.Diagnostic> newDiagnostics) {
    _diagnostics = newDiagnostics;
    notifyListeners();
  }

  void showHover(int line, int character) {
    final currentPosition = Position(line: line, column: character);

    if (_lastHoverPosition != currentPosition && !_isHoveringPopup) {
      _hoverTimer?.cancel();
      _lastHoverPosition = currentPosition;
      _hoverTimer = Timer(const Duration(milliseconds: 300), () async {
        if (_lastHoverPosition == currentPosition && !_isHoveringPopup) {
          final response = await lspService.getHover(line, character);

          // Filter diagnostics that match the current position
          final matchingDiagnostics = _diagnostics.where((diagnostic) {
            final range = diagnostic.range;
            return line >= range.start.line &&
                line <= range.end.line &&
                character >= range.start.character &&
                character <= range.end.character;
          }).toList();

          if (response != null) {
            var content = response['contents']?['value'];
            if (content == null || content.isEmpty) content = '';

            EditorEventBus.emit(HoverEvent(
              content: content,
              line: line,
              character: character,
              diagnostics: matchingDiagnostics,
            ));
          }
        }
      });
    }
  }

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
  void selectNextSuggestion() {
    if (showCompletions && suggestions.isNotEmpty) {
      selectedSuggestionIndexNotifier.value =
          (selectedSuggestionIndexNotifier.value + 1) % suggestions.length;
      notifyListeners();
    }
  }

  void selectPreviousSuggestion() {
    if (showCompletions && suggestions.isNotEmpty) {
      selectedSuggestionIndexNotifier.value =
          (selectedSuggestionIndexNotifier.value - 1 + suggestions.length) %
              suggestions.length;
      notifyListeners();
    }
  }

  void resetSuggestionSelection() {
    selectedSuggestionIndexNotifier.value = 0;
    notifyListeners();
  }

  String _getPrefix(String line, int column) {
    final pattern = RegExp(r'\w+$');
    final match = pattern.firstMatch(line.substring(0, column));
    return match?.group(0) ?? '';
  }

  void updateCompletions() {
    if (editorCursorManager.cursors.isEmpty) {
      showCompletions = false;
      suggestions = [];
      notifyListeners();
      return;
    }

    // Get prefixes for all cursors
    final prefixes = editorCursorManager.cursors.map((cursor) {
      final line = buffer.getLine(cursor.line);
      return _getPrefix(line, cursor.column);
    }).toSet();

    // Only show completions if all cursors have the same non-empty prefix
    if (prefixes.length == 1 && prefixes.first.isNotEmpty) {
      suggestions = _completionService.getSuggestions(prefixes.first);
      showCompletions = suggestions.isNotEmpty &&
          (suggestions.length > 1 || suggestions[0].label != prefixes.first);
    } else {
      showCompletions = false;
      suggestions = [];
    }

    notifyListeners();
  }

  // Saving methods
  Future<void> save() async {
    if (path.isEmpty || path.substring(0, 6) == '__temp') {
      // For new untitled files, we need to use saveFileAs
      await saveFileAs(path);
    } else {
      await saveFile(path);
    }

    // After successful save, mark buffer as clean
    _buffer.isDirty = false;

    notifyListeners();
  }

  Future<bool> saveFileAs(String path) async {
    try {
      final success = await editorFileManager.saveFileAs(path);
      if (success) {
        _buffer.isDirty = false;
        _emitFileChangedEvent();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _emitErrorEvent('Failed to save file', path, e.toString());
      return false;
    }
  }

  void acceptCompletion(CompletionItem item) {
    // Sort cursors from bottom to top to maintain correct positions
    final sortedCursors = List<Cursor>.from(editorCursorManager.cursors)
      ..sort((a, b) => b.line.compareTo(a.line));

    for (var cursor in sortedCursors) {
      final line = buffer.getLine(cursor.line);
      final prefix = _getPrefix(line, cursor.column);

      if (prefix.isEmpty) continue;

      final newLine = line.substring(0, cursor.column - prefix.length) +
          item.label +
          line.substring(cursor.column);

      buffer.setLine(cursor.line, newLine);
      cursor.column = cursor.column - prefix.length + item.label.length;
    }

    showCompletions = false;
    resetSuggestionSelection();
    editorCursorManager.mergeCursorsIfNeeded();
    notifyListeners();
  }

  // Misc

  TextRange? getWordRangeAt(int line, int column) {
    if (line < 0 || line >= buffer.lines.length) return null;

    final lineText = buffer.lines[line];
    if (column < 0 || column >= lineText.length) return null;

    // Find word boundaries
    int start = column;
    int end = column;

    while (start > 0 && _isWordChar(lineText[start - 1])) {
      start--;
    }

    while (end < lineText.length && _isWordChar(lineText[end])) {
      end++;
    }

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

  bool _isWordChar(String char) {
    return RegExp(r'[a-zA-Z0-9_]').hasMatch(char);
  }

  void _updateBreadcrumbs(int line, int column) {
    if (!path.toLowerCase().endsWith('.dart')) {
      _breadcrumbs = [];
      return;
    }

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
    _emitSelectionChangedEvent();

    notifyListeners();
  }

  void updateSelection() {
    editorSelectionManager.updateSelection(editorCursorManager.cursors);
    _emitSelectionChangedEvent();

    notifyListeners();
  }

  void clearSelection() {
    editorSelectionManager.clearAll();
    notifyListeners();
    _emitSelectionChangedEvent();
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
    _emitClipboardEvent(getSelectedText(), ClipboardAction.copy);
  }

  void cut() {
    final textBeforeCut = getSelectedText();
    commandHandler.cut();
    updateCompletions();
    _emitTextChangedEvent();
    _emitClipboardEvent(textBeforeCut, ClipboardAction.cut);
  }

  void paste() {
    commandHandler.paste();
    updateCompletions();
    _emitTextChangedEvent();
    _emitClipboardEvent(getSelectedText(), ClipboardAction.paste);
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
    _emitSelectionChangedEvent();
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    selectionHandler.selectLine(extend, lineNumber);
    _emitSelectionChangedEvent();
    notifyListeners();
  }

  void startSelection() {
    selectionHandler.startSelection();
    _emitSelectionChangedEvent();
    notifyListeners();
  }

  bool hasSelection() => selectionHandler.hasSelection();
  TextRange getSelectedLineRange() => selectionHandler.getSelectedLineRange();

  String getSelectedText() {
    return editorSelectionManager.getSelectedText(_buffer);
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

  Future<bool> saveFile(String path) async {
    try {
      final success = await editorFileManager.saveFile(path);
      if (success) {
        _buffer.isDirty = false;
        _emitFileChangedEvent();
        notifyListeners();
      }
      return success;
    } catch (e) {
      _emitErrorEvent('Failed to save file', path, e.toString());
      return false;
    }
  }

  bool get isEmpty => buffer.isEmpty;

  void openFile(String content) {
    editorCursorManager.reset();
    clearSelection();
    editorFileManager.openFile(content);
    scrollState.updateVerticalScrollOffset(0);
    scrollState.updateHorizontalScrollOffset(0);
    resetGutterScroll();
    _updateBreadcrumbs(0, 0);
    _emitFileChangedEvent();

    if (path.isNotEmpty && !path.startsWith('__temp')) {
      CommandPaletteService.addRecentFile(path);
    }

    notifyListeners();
  }
}
