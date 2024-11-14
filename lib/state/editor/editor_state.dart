import 'dart:io';
import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

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
  late final FoldingManager foldingManager;
  final String id = UniqueKey().toString();
  EditorScrollState scrollState = EditorScrollState();
  final Buffer _buffer = Buffer();
  VoidCallback resetGutterScroll;
  String path = '';
  final UndoRedoManager undoRedoManager = UndoRedoManager();
  final EditorLayoutService editorLayoutService;
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
  int _getColumnAtX(
      double x, String lineText, Function(String line) measureLineWidth) {
    double currentWidth = 0;
    int targetColumn = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth = editorLayoutService.config.charWidth;
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    return targetColumn;
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

  bool _isValidLineNumber(int lineNumber) {
    return lineNumber >= 0 && lineNumber < _buffer.lineCount;
  }

  void requestFocus() {
    notifyListeners();
  }

  void recalculateVisibleLines() {
    notifyListeners();
  }

  // FoldingManager methods
  void _unfoldBeforeDelete() {
    for (var cursor in editorCursorManager.cursors) {
      _unfoldAtCursorForDelete(cursor);
      _unfoldAtClosingSymbolForDelete(cursor);
    }
  }

  void _unfoldAtCursorForDelete(Cursor cursor) {
    final lineContent = buffer.getLine(cursor.line);
    if (cursor.column < lineContent.length) {
      final charAtCursor = lineContent[cursor.column];

      if ('{([<'.contains(charAtCursor) &&
          foldingManager.isFolded(cursor.line)) {
        foldingManager.unfold(cursor.line);
      }
    }
  }

  void _unfoldAtClosingSymbolForDelete(Cursor cursor) {
    for (var entry in foldingManager.foldedRegions.entries) {
      final foldStart = entry.key;
      final foldEnd = entry.value;
      final lineContent = buffer.getLine(foldEnd);

      if (foldingManager.isCursorAtClosingSymbol(
          cursor, lineContent, foldEnd, false)) {
        foldingManager.unfold(foldStart);
        break;
      }
    }
  }

  void _updateFoldedRegions() {
    final affectedLines =
        editorCursorManager.cursors.map((cursor) => cursor.line).toSet();
    foldingManager.updateFoldedRegionsAfterEdit(affectedLines);
  }

  void _unfoldBeforeBackspace() {
    for (var cursor in editorCursorManager.cursors) {
      foldingManager.unfoldAtCursor(cursor);
      foldingManager.unfoldBeforeCursor(cursor);
      foldingManager.unfoldAtClosingSymbol(cursor);
    }
  }

  void _updateFoldedRegionsAfterEdit(Set<int> affectedLines) {
    // Get all folded regions that contain affected lines
    final regionsToCheck = <int, int>{};

    // Also check the line itself for any fold starts
    for (final line in affectedLines) {
      if (buffer.foldedRanges.containsKey(line)) {
        regionsToCheck[line] = buffer.foldedRanges[line]!;
      }
    }

    // Check each affected folded region
    for (final entry in regionsToCheck.entries) {
      final startLine = entry.key;
      final originalEndLine = entry.value;

      // Check if the folded region is still valid
      final newEndLine =
          foldingManager.getFoldableRegionEnd(startLine, buffer.lines);
      if (newEndLine == null || newEndLine != originalEndLine) {
        // Region is no longer valid, unfold it
        buffer.unfoldLines(startLine);
        foldingManager.toggleFold(startLine, originalEndLine);
      }
    }
  }

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

    final affectedLines = <int>{};
    var sortedCursors = List.from(editorCursorManager.cursors)
      ..sort((a, b) {
        if (a.line != b.line) return a.line.compareTo(b.line);
        return a.column.compareTo(b.column);
      });

    for (int i = 0; i < sortedCursors.length; i++) {
      var currentCursor = sortedCursors[i];
      affectedLines.add(currentCursor.line);

      // Apply adjustments to later cursors
      if (i < sortedCursors.length - 1) {
        for (int j = i + 1; j < sortedCursors.length; j++) {
          var laterCursor = sortedCursors[j];
          if (laterCursor.line == currentCursor.line &&
              laterCursor.column > currentCursor.column) {
            laterCursor.column += c.length;
          }
        }
      }

      executeCommand(TextInsertCommand(
          _buffer, c, currentCursor.line, currentCursor.column, currentCursor));
    }

    _updateFoldedRegionsAfterEdit(affectedLines);
  }

  void insertNewLine() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
    }

    editorCursorManager.insertNewLine(_buffer);
    notifyListeners();
  }

  int _getBufferLineFromVisualLine(int visualLine) {
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (currentVisualLine < visualLine && bufferLine < buffer.lineCount) {
      if (!foldingManager.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    while (bufferLine < buffer.lineCount &&
        foldingManager.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return bufferLine;
  }

  void executeCommand(Command command) {
    undoRedoManager.executeCommand(command);
    notifyListeners();
  }

  (int, int) getBufferPosition(int visualLine) {
    int currentVisualLine = 0;
    int currentBufferLine = 0;

    while (currentVisualLine < visualLine &&
        currentBufferLine < _buffer.lineCount) {
      if (!foldingManager.isLineHidden(currentBufferLine)) {
        currentVisualLine++;
      }
      currentBufferLine++;
    }

    return (currentBufferLine, 0);
  }

  void _performBackspace() {
    editorCursorManager.backspace(buffer);
    buffer.incrementVersion();
  }

  void _performDelete() {
    editorCursorManager.delete(buffer);
    buffer.incrementVersion();
  }

  void delete() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    _unfoldBeforeDelete();
    _performDelete();
    _updateFoldedRegions();
    notifyListeners();
  }

  void backspace() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    _unfoldBeforeBackspace();
    _performBackspace();
    _updateFoldedRegions();
    notifyListeners();
  }

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
  void handleDragStart(double dy, double dx,
      Function(String line) measureLineWidth, bool isAltPressed) {
    handleTap(dy, dx, measureLineWidth, isAltPressed);
    startSelection();
    notifyListeners();
  }

  void handleDragUpdate(
      double dy, double dx, Function(String) measureLineWidth) {
    // Calculate max visual line based on buffer size
    int maxVisualLine = buffer.lineCount - 1;

    // Clamp visual line to valid range
    int visualLine =
        (dy ~/ editorLayoutService.config.lineHeight).clamp(0, maxVisualLine);

    int bufferLine = _getBufferLineFromVisualLine(visualLine);
    bufferLine = bufferLine.clamp(0, buffer.lineCount - 1);

    // Check if we're selecting a folded region
    bool isFolded = false;
    int? foldStart;
    int? foldEnd;

    for (final entry in buffer.foldedRanges.entries) {
      if (bufferLine >= entry.key && bufferLine <= entry.value) {
        isFolded = true;
        foldStart = entry.key;
        foldEnd = entry.value;
        break;
      }
    }

    String lineText = buffer.getLine(bufferLine);
    int targetColumn = _getColumnAtX(dx, lineText, measureLineWidth);

    editorCursorManager.clearAll();
    editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));

    if (isFolded && foldStart != null && foldEnd != null) {
      Selection? currentSelection = editorSelectionManager.selections.isNotEmpty
          ? editorSelectionManager.selections.first
          : null;

      if (currentSelection != null) {
        bool isSelectingBackwards = currentSelection.anchorLine > bufferLine ||
            (currentSelection.anchorLine == bufferLine &&
                targetColumn < currentSelection.anchorColumn);

        if (bufferLine <= foldStart && isSelectingBackwards) {
          // When selecting backwards, maintain the target column
          editorSelectionManager.updateSelectionToLine(
              buffer, foldStart, targetColumn);
        } else if (bufferLine >= foldStart && bufferLine <= foldEnd) {
          // When selecting within the fold
          editorSelectionManager.updateSelectionToLine(
              buffer, bufferLine, targetColumn);
        } else {
          // When selecting outside the fold
          editorSelectionManager.updateSelectionToLine(
              buffer, foldEnd, buffer.getLineLength(foldEnd));
        }
      }
    } else {
      updateSelection();
    }

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

  Future<bool> handleSpecialKeys(bool isControlPressed, bool isShiftPressed,
      LogicalKeyboardKey key) async {
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
      case LogicalKeyboardKey.keyQ:
        if (isControlPressed) {
          // TODO check for unsaved files
          exit(0);
        }
      case LogicalKeyboardKey.keyO:
        if (isControlPressed) {
          String? selectedDirectory =
              await FilePicker.platform.getDirectoryPath();

          if (onDirectoryChanged != null) {
            onDirectoryChanged!(selectedDirectory ?? fileService.rootDirectory);
          }
          return true;
        }
      case LogicalKeyboardKey.keyF:
        if (isControlPressed) {
          await windowManager
              .setFullScreen(!await windowManager.isFullScreen());
          return true;
        }
    }

    return false;
  }

  void handleTap(double dy, double dx, Function(String) measureLineWidth,
      bool isAltPressed) {
    int visualLine = dy ~/ editorLayoutService.config.lineHeight;
    int bufferLine = _getBufferLineFromVisualLine(visualLine);

    String lineText = buffer.getLine(bufferLine);
    int targetColumn = _getColumnAtX(dx, lineText, measureLineWidth);

    if (!isAltPressed) {
      editorCursorManager.clearAll();
      editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));
      clearSelection();
    } else {
      // Multi-cursor handling
      if (editorCursorManager.cursorExistsAtPosition(
          bufferLine, targetColumn)) {
        if (editorCursorManager.cursors.length > 1) {
          editorCursorManager.removeCursor(Cursor(bufferLine, targetColumn));
        }
      } else {
        editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));
      }
      clearSelection();
    }
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

  void selectLine(bool extend, int lineNumber) {
    if (!_isValidLineNumber(lineNumber)) return;

    final foldedRegion = foldingManager.getFoldedRegionForLine(lineNumber);
    if (foldedRegion != null) {
      _selectFoldedRegion(extend, foldedRegion);
    } else {
      _selectSingleLine(extend, lineNumber);
    }

    notifyListeners();
  }

  TextRange getSelectedLineRange() {
    if (!editorSelectionManager.hasSelection()) {
      // If no selection, return range containing only current line
      int currentLine = editorCursorManager.getCursorLine();
      return TextRange(start: currentLine, end: currentLine);
    }

    // Get all selections and find min/max lines
    var selections = editorSelectionManager.selections;
    int minLine = _buffer.lineCount;
    int maxLine = 0;

    for (var selection in selections) {
      minLine = min(minLine, min(selection.startLine, selection.endLine));
      maxLine = max(maxLine, max(selection.startLine, selection.endLine));
    }

    return TextRange(start: minLine, end: maxLine);
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

    // Sort selections in reverse order to handle overlapping selections correctly
    var sortedSelections =
        List<Selection>.from(editorSelectionManager.selections)
          ..sort((a, b) => b.startLine.compareTo(a.startLine));

    // Track folded regions that need to be removed
    final foldedRegionsToRemove = <int>{};

    // Check all folded regions that intersect with selections
    for (var selection in sortedSelections) {
      final startLine = min(selection.startLine, selection.endLine);
      final endLine = max(selection.startLine, selection.endLine);

      // Check each folded region
      for (final entry in buffer.foldedRanges.entries) {
        final foldStart = entry.key;
        final foldEnd = entry.value;

        // Check if selection contains closing bracket of fold
        if (foldingManager.selectionContainsFoldEnd(selection, foldEnd)) {
          foldedRegionsToRemove.add(foldStart);
          continue;
        }

        // Cases where we need to remove the folded region:
        // 1. Selection completely contains the folded region
        // 2. Selection starts within the folded region
        // 3. Selection ends within the folded region
        // 4. Folded region completely contains the selection
        if ((startLine <= foldStart && endLine >= foldEnd) || // Case 1
            (startLine >= foldStart && startLine <= foldEnd) || // Case 2
            (endLine >= foldStart && endLine <= foldEnd) || // Case 3
            (foldStart <= startLine && foldEnd >= endLine)) {
          // Case 4
          foldedRegionsToRemove.add(foldStart);
        }
      }
    }

    // Remove affected folded regions before deleting text
    for (final foldStart in foldedRegionsToRemove) {
      buffer.unfoldLines(foldStart);
      foldingManager.toggleFold(
          foldStart, buffer.foldedRanges[foldStart] ?? foldStart);
    }

    // Perform deletion
    var newStartLinesColumns = editorSelectionManager.deleteSelection(buffer);
    editorCursorManager.setAllCursors(newStartLinesColumns);
    buffer.incrementVersion();

    // Clean up any remaining folded regions that might be invalid
    final remainingFolds = Map<int, int>.from(buffer.foldedRanges);
    for (final entry in remainingFolds.entries) {
      if (entry.key >= buffer.lineCount || entry.value >= buffer.lineCount) {
        buffer.unfoldLines(entry.key);
        foldingManager.toggleFold(entry.key, entry.value);
      }
    }

    notifyListeners();
  }

  void _selectFoldedRegion(bool extend, MapEntry<int, int> foldedRegion) {
    editorSelectionManager.selectLineRange(
      buffer,
      extend,
      foldedRegion.key,
      foldedRegion.value,
    );
    _updateCursorForFoldedRegion(foldedRegion.value);
  }

  void startSelection() {
    editorSelectionManager.startSelection(editorCursorManager.cursors);
  }

  void _selectSingleLine(bool extend, int lineNumber) {
    editorSelectionManager.selectLine(buffer, extend, lineNumber);
    _updateCursorForSingleLine(lineNumber);
  }

  bool hasSelection() {
    return editorSelectionManager.hasSelection();
  }

  List<Selection> getCurrentSelections() {
    return editorSelectionManager.selections.toList();
  }

  // CursorManager methods
  void toggleCaret() {
    editorCursorManager.toggleCaret();
    notifyListeners();
  }

  void _updateCursorForFoldedRegion(int endLine) {
    editorCursorManager.clearAll();
    editorCursorManager
        .addCursor(Cursor(endLine, _buffer.getLineLength(endLine)));
  }

  void _updateCursorForSingleLine(int lineNumber) {
    editorCursorManager.clearAll();
    editorCursorManager
        .addCursor(Cursor(lineNumber, _buffer.getLineLength(lineNumber)));
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
}
