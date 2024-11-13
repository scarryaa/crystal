import 'dart:io';
import 'dart:math';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/command.dart';
import 'package:crystal/models/editor/cursor_shape.dart';
import 'package:crystal/models/editor/folding_state.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';
import 'package:crystal/utils/utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:window_manager/window_manager.dart';

class EditorState extends ChangeNotifier {
  late final FoldingManager foldingManager;
  final FoldingState foldingState = FoldingState();
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
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final Future<void> Function(String) tapCallback;
  bool isPinned = false;
  String? relativePath = '';
  final closingSymbols = ['}', ')', ']', '>'];

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
    foldingManager = FoldingManager(_buffer);
  }

  void toggleFold(int startLine, int endLine, {Map<int, int>? nestedFolds}) {
    foldingState.toggleFold(startLine, endLine, nestedFolds: nestedFolds);
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

  (int, int) getBufferPosition(int visualLine) {
    int currentVisualLine = 0;
    int currentBufferLine = 0;

    while (currentVisualLine < visualLine &&
        currentBufferLine < _buffer.lineCount) {
      if (!foldingState.isLineHidden(currentBufferLine)) {
        currentVisualLine++;
      }
      currentBufferLine++;
    }

    return (currentBufferLine, 0);
  }

  int getCursorLine() {
    // Return the line number of the first cursor
    if (editorCursorManager.cursors.isEmpty) {
      return 0;
    }
    return editorCursorManager.cursors.first.line;
  }

  TextRange getSelectedLineRange() {
    if (!editorSelectionManager.hasSelection()) {
      // If no selection, return range containing only current line
      int currentLine = getCursorLine();
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

  int getLastPastedLineCount() {
    // Get the last command from undo stack
    if (_undoStack.isEmpty) {
      return 0;
    }

    Command lastCommand = _undoStack.last;
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
        if (_selectionContainsFoldEnd(selection, foldEnd)) {
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
      foldingState.toggleFold(
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
        foldingState.toggleFold(entry.key, entry.value);
      }
    }

    notifyListeners();
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
        foldingState.toggleFold(startLine, originalEndLine);
      }
    }
  }

  bool _selectionContainsFoldEnd(Selection selection, int foldEndLine) {
    final adjustedEndLine = foldEndLine + 1;
    final endLineContent = buffer.getLine(adjustedEndLine);
    if (endLineContent == null) return false;

    // Find the last closing symbol in the line
    String? closingSymbol;
    int symbolIndex = -1;

    for (final symbol in closingSymbols) {
      final lastIndex = endLineContent.lastIndexOf(symbol);
      if (lastIndex > symbolIndex) {
        symbolIndex = lastIndex;
        closingSymbol = symbol;
      }
    }

    if (closingSymbol == null || symbolIndex == -1) return false;

    // Check if the selection contains the closing symbol
    if (selection.startLine == adjustedEndLine &&
        selection.endLine == adjustedEndLine) {
      // Single line selection
      final selStart = min(selection.startColumn, selection.endColumn);
      final selEnd = max(selection.startColumn, selection.endColumn);
      return symbolIndex >= selStart && symbolIndex <= selEnd;
    } else if (selection.startLine <= adjustedEndLine &&
        selection.endLine >= adjustedEndLine) {
      // Multi-line selection
      if (selection.startLine == adjustedEndLine) {
        // Check if selection start is before or at symbol
        return selection.startColumn <= symbolIndex;
      } else if (selection.endLine == adjustedEndLine) {
        // Check if selection end is after or at symbol
        return selection.endColumn >= symbolIndex;
      }
      return true; // Whole line is selected
    }

    return false;
  }

  bool _isCursorAtClosingSymbol(
    Cursor cursor,
    String lineContent,
    int lineNumber,
    bool isBackspace,
  ) {
    for (final symbol in closingSymbols) {
      final symbolIndex = lineContent.lastIndexOf(symbol);
      if (symbolIndex == -1) continue;

      if (isBackspace) {
        // For backspace, check if cursor is:
        // 1. Right after the symbol
        // 2. At the symbol
        // 3. Just before the symbol (for line endings)
        if (cursor.line == lineNumber &&
            (cursor.column == symbolIndex + 1 ||
                cursor.column == symbolIndex ||
                cursor.column == symbolIndex - 1)) {
          return true;
        }
      } else {
        // For delete, check if cursor is:
        // 1. Just before the symbol
        // 2. At the symbol
        if (cursor.line == lineNumber &&
            (cursor.column == symbolIndex ||
                cursor.column == symbolIndex - 1)) {
          return true;
        }
      }
    }
    return false;
  }

  void backspace() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    // Check for opening brackets at cursor positions
    for (var cursor in editorCursorManager.cursors) {
      if (cursor.column > 0) {
        final lineContent = buffer.getLine(cursor.line);
        final charBeforeCursor = lineContent[cursor.column - 1];

        // If character before cursor is an opening bracket and this line starts a fold
        if ('{([<'.contains(charBeforeCursor) &&
            buffer.foldedRanges.containsKey(cursor.line)) {
          // Unfold before deleting
          final foldEnd = buffer.foldedRanges[cursor.line]!;
          buffer.unfoldLines(cursor.line);
          foldingState.toggleFold(cursor.line, foldEnd);
        }
      }
    }

    // Check if any cursor is about to delete into a folded region
    for (var cursor in editorCursorManager.cursors) {
      // If cursor is at column 0 and previous line is folded or within a fold
      if (cursor.column == 0 && cursor.line > 0) {
        // Check each folded region
        for (var entry in buffer.foldedRanges.entries) {
          final foldStart = entry.key;
          final foldEnd = entry.value;

          // Check if the line before cursor is within or at the end of a fold
          if (cursor.line - 1 >= foldStart && cursor.line - 1 <= foldEnd) {
            // Unfold before performing backspace
            buffer.unfoldLines(foldStart);
            foldingState.toggleFold(foldStart, foldEnd + 1);
            break;
          }
        }
      }
    }

    // Check if any cursor is about to delete a closing symbol of a folded region
    for (var cursor in editorCursorManager.cursors) {
      // Check each folded region
      for (var entry in buffer.foldedRanges.entries) {
        final foldStart = entry.key;
        final foldEnd = entry.value + 1;
        // Get the actual content of the line ending
        final lineContent = buffer.getLine(foldEnd);
        if (_isCursorAtClosingSymbol(cursor, lineContent, foldEnd, true)) {
          // Unfold before performing backspace
          buffer.unfoldLines(foldStart);
          foldingState.toggleFold(foldStart, foldEnd);
          break;
        }
      }
    }

    final affectedLines =
        editorCursorManager.cursors.map((cursor) => cursor.line).toSet();
    editorCursorManager.backspace(_buffer);
    _buffer.incrementVersion();
    _updateFoldedRegionsAfterEdit(affectedLines);
    notifyListeners();
  }

  void delete() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
      return;
    }

    // Check for opening brackets at cursor positions
    for (var cursor in editorCursorManager.cursors) {
      final lineContent = buffer.getLine(cursor.line);
      if (cursor.column < lineContent.length) {
        final charAtCursor = lineContent[cursor.column];

        // If character at cursor is an opening bracket and this line starts a fold
        if ('{([<'.contains(charAtCursor) &&
            buffer.foldedRanges.containsKey(cursor.line)) {
          // Unfold before deleting
          final foldEnd = buffer.foldedRanges[cursor.line]!;
          buffer.unfoldLines(cursor.line);
          foldingState.toggleFold(cursor.line, foldEnd);
        }
      }
    }

    // Check if any cursor is about to delete a closing symbol of a folded region
    for (var cursor in editorCursorManager.cursors) {
      // Check each folded region
      for (var entry in buffer.foldedRanges.entries) {
        final foldStart = entry.key;
        final foldEnd = entry.value + 1;
        // Get the actual content of the line ending
        final lineContent = buffer.getLine(foldEnd);

        if (_isCursorAtClosingSymbol(cursor, lineContent, foldEnd, false)) {
          // Unfold before performing delete
          buffer.unfoldLines(foldStart);
          foldingState.toggleFold(foldStart, foldEnd);
          break;
        }
      }
    }

    final affectedLines =
        editorCursorManager.cursors.map((cursor) => cursor.line).toSet();
    editorCursorManager.delete(buffer);
    _buffer.incrementVersion();
    _updateFoldedRegionsAfterEdit(affectedLines);
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

  bool hasSelection() {
    return editorSelectionManager.hasSelection();
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

  int _getBufferLineFromVisualLine(int visualLine) {
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (currentVisualLine < visualLine && bufferLine < buffer.lineCount) {
      if (!foldingState.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    while (bufferLine < buffer.lineCount &&
        foldingState.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return bufferLine;
  }

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

  void insertNewLine() {
    if (editorSelectionManager.hasSelection()) {
      deleteSelection();
    }

    editorCursorManager.insertNewLine(_buffer);
    notifyListeners();
  }

  void selectLine(bool extend, int lineNumber) {
    if (lineNumber < 0 || lineNumber >= _buffer.lineCount) return;

    // Check if line is in a folded region
    for (final entry in foldingState.foldingRanges.entries) {
      if (lineNumber >= entry.key && lineNumber <= entry.value) {
        // Select entire folded region
        editorSelectionManager.selectLineRange(
            buffer, extend, entry.key, entry.value);
        editorCursorManager.clearAll();
        editorCursorManager
            .addCursor(Cursor(entry.value, _buffer.getLineLength(entry.value)));
        notifyListeners();
        return;
      }
    }

    // Normal line selection if not in folded region
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

    // Handle each cursor separately
    for (var cursor in editorCursorManager.cursors) {
      int nextLine = cursor.line + 1;

      // Skip over folded regions
      while (
          nextLine < _buffer.lineCount && foldingState.isLineHidden(nextLine)) {
        nextLine++;
      }

      // If we're on a fold start, jump to after the fold
      if (buffer.foldedRanges.containsKey(cursor.line)) {
        nextLine = buffer.foldedRanges[cursor.line]! + 1;
      }

      if (nextLine < _buffer.lineCount) {
        cursor.line = nextLine;
        // Maintain the same column position if possible
        cursor.column = min(cursor.column, _buffer.getLineLength(nextLine));
      }
    }

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

    // Handle each cursor separately
    for (var cursor in editorCursorManager.cursors) {
      int prevLine = cursor.line - 1;

      // Skip over folded regions
      while (prevLine >= 0 && foldingState.isLineHidden(prevLine)) {
        prevLine--;
      }

      // If we're after a fold end, jump to the fold start
      for (var entry in buffer.foldedRanges.entries) {
        if (cursor.line == entry.value + 1) {
          prevLine = entry.key;
          break;
        }
      }

      if (prevLine >= 0) {
        cursor.line = prevLine;
        // Maintain the same column position if possible
        cursor.column = min(cursor.column, _buffer.getLineLength(prevLine));
      }
    }

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

    for (var cursor in editorCursorManager.cursors) {
      int lineLength = _buffer.getLineLength(cursor.line);

      if (cursor.column < lineLength) {
        cursor.column++;
      } else if (cursor.line < _buffer.lineCount - 1) {
        // Moving to next line
        int nextLine = cursor.line + 1;

        // Skip folded regions
        while (nextLine < _buffer.lineCount &&
            foldingState.isLineHidden(nextLine)) {
          nextLine++;
        }

        // If we're on a fold start, jump to after the fold
        if (buffer.foldedRanges.containsKey(cursor.line)) {
          nextLine = buffer.foldedRanges[cursor.line]! + 1;
        }

        if (nextLine < _buffer.lineCount) {
          cursor.line = nextLine;
          cursor.column = 0;
        }
      }
    }

    if (isShiftPressed) {
      updateSelection();
    } else {
      clearSelection();
    }
    notifyListeners();
  }

  void moveCursorLeft(bool isShiftPressed) {
    if (!editorSelectionManager.hasSelection() && isShiftPressed) {
      startSelection();
    }

    for (var cursor in editorCursorManager.cursors) {
      if (cursor.column > 0) {
        cursor.column--;
      } else if (cursor.line > 0) {
        // Moving to previous line
        int prevLine = cursor.line - 1;

        // Skip folded regions
        while (prevLine >= 0 && foldingState.isLineHidden(prevLine)) {
          prevLine--;
        }

        // If we're after a fold end, jump to the fold start
        for (var entry in buffer.foldedRanges.entries) {
          if (cursor.line == entry.value + 1) {
            prevLine = entry.key;
            break;
          }
        }

        if (prevLine >= 0) {
          cursor.line = prevLine;
          cursor.column = _buffer.getLineLength(prevLine);
        }
      }
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
