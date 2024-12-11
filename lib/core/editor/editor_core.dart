import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/selection_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager bufferManager;
  final SelectionManager selectionManager;
  final CursorManager cursorManager;
  final EditorConfig _editorConfig;
  final String path;

  void Function()? forceRefresh;
  void Function(int line, int column)? onCursorMove;
  void Function(String)? onEdit;
  void Function(int, int, int, int, int)? onSelectionChange;

  EditorCore({
    required this.bufferManager,
    required this.selectionManager,
    required this.cursorManager,
    required editorConfig,
    this.onCursorMove,
    this.forceRefresh,
    required this.path,
  }) : _editorConfig = editorConfig;

  void moveTo(int index, int line, int column) {
    cursorManager.moveTo(index, line, column);
    onCursorMove?.call(line, column);
    notifyListeners();
  }

  void moveLeft() {
    cursorManager.moveLeft();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveRight() {
    cursorManager.moveRight();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveUp() {
    cursorManager.moveUp();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveDown() {
    cursorManager.moveDown();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void addCursor(int line, int index) {
    cursorManager.addCursor(Cursor(line: line, index: index));
    cursorManager.sortCursors();
  }

  void insertChar(String char) {
    deleteSelectionsIfNeeded();
    bufferManager.insertCharacter(char);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void insertLine() {
    deleteSelectionsIfNeeded();
    bufferManager.insertNewline();
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void delete(int length) {
    if (deleteSelectionsIfNeeded()) return;
    bufferManager.delete(length);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void deleteForwards(int length) {
    if (deleteSelectionsIfNeeded()) return;
    bufferManager.deleteForwards(length);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void setBuffer(String content) {
    bufferManager.setText(content);
    onEdit?.call(bufferManager.toString());
  }

  void copy() {
    Clipboard.setData(
        ClipboardData(text: selectionManager.getSelectedText(bufferManager)));
    notifyListeners();
  }

  void cut() {
    Clipboard.setData(
        ClipboardData(text: selectionManager.getSelectedText(bufferManager)));
    deleteSelectionsIfNeeded();
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  Future<void> paste() async {
    final String? clipboardData =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (clipboardData == null) return;

    deleteSelectionsIfNeeded();
    bufferManager.insertString(clipboardData);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void selectAll() {
    selectionManager.selectAll(bufferManager);
    cursorManager.clearCursors();
    cursorManager.moveTo(0, bufferManager.lines.length - 1,
        bufferManager.lines[bufferManager.lines.length - 1].length);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  bool hasSelection() {
    return selectionManager.hasSelection();
  }

  void startSelection() {
    selectionManager.startSelection(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void clearSelection() {
    selectionManager.clearSelections();
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void _sortSelections() {
    selectionManager.selections.sort((a, b) {
      final int endComparison = b.endIndex.compareTo(a.endIndex);
      return endComparison != 0
          ? endComparison
          : b.startLine.compareTo(a.startLine);
    });
  }

  void _adjustOverlappingSelections(Selection currentSelection) {
    for (var previousSelection in selectionManager.selections) {
      if (previousSelection.endIndex < currentSelection.endIndex &&
          previousSelection.startLine == currentSelection.endLine) {
        final adjustmentAmount =
            previousSelection.endIndex - previousSelection.startIndex;

        currentSelection.startIndex -= adjustmentAmount;
        currentSelection.endIndex -= adjustmentAmount;
      }
    }
  }

  Map<int, int> _deleteSelections() {
    final Map<int, int> lineAdjustments = {};
    final Map<int, int> indexAdjustments = {};
    bool selectionDeleted = false;

    // Sort selections before deletion
    _sortSelections();

    for (var selection in selectionManager.selections) {
      final beforeLines = bufferManager.lines.length;

      // Delete the current selection
      final (int, int) result =
          selection.deleteSelection(bufferManager, cursorPosition);

      // Track line adjustments
      lineAdjustments[selection.startLine] = result.$1;

      // Handle overlapping selections
      _adjustOverlappingSelections(selection);

      // Update index adjustments
      indexAdjustments.update(selection.startLine, (value) => value + result.$2,
          ifAbsent: () => result.$2);

      // Trigger callbacks if lines changed
      _triggerSelectionDeletionCallbacks(
          selection, beforeLines, selectionDeleted);

      selectionDeleted = true;
    }

    return lineAdjustments;
  }

  void _adjustCursors(Map<int, int> lineAdjustments) {
    for (var selection in selectionManager.selections) {
      final int line = selection.startLine;

      // Remove duplicate cursors
      _removeDuplicateCursors(selection);

      // Calculate total line adjustment
      final int totalAdjustment =
          _calculateTotalLineAdjustment(lineAdjustments, line);

      // Add new cursor at adjusted position
      cursorManager.addCursor(Cursor(
          line: selection.startLine - totalAdjustment,
          index: selection.startIndex));
    }

    // Merge cursors if needed
    cursorManager.mergeCursorsIfNeeded();
  }

  void _removeDuplicateCursors(Selection selection) {
    final duplicateCursor = cursorManager.cursors.firstWhere(
        (c) =>
            c.index == selection.anchor &&
            (c.line == selection.startLine || c.line == selection.endLine),
        orElse: () => Cursor(line: -1, index: -1));

    if (duplicateCursor != Cursor(line: -1, index: -1)) {
      cursorManager.removeCursor(duplicateCursor, keepAnchor: false);
    }
  }

  int _calculateTotalLineAdjustment(
      Map<int, int> lineAdjustments, int currentLine) {
    return lineAdjustments.entries
        .where((entry) => entry.key < currentLine)
        .map((entry) => entry.value)
        .fold(0, (total, adjustment) => total + adjustment);
  }

  void _triggerSelectionDeletionCallbacks(
      Selection selection, int beforeLines, bool selectionDeleted) {
    // Trigger refresh if lines changed
    if (beforeLines != bufferManager.lines.length) {
      forceRefresh?.call();
    }

    // Cursor move callback
    onCursorMove?.call(cursorLine, cursorPosition);

    // Edit callback
    onEdit?.call(bufferManager.toString());

    // Selection change callback
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
  }

  bool deleteSelectionsIfNeeded() {
    // Check if there are any selections
    if (!selectionManager.hasSelection()) return false;

    final lineAdjustments = _deleteSelections();
    _adjustCursors(lineAdjustments);
    selectionManager.clearSelections();
    notifyListeners.call();

    return true;
  }

  void handleSelection(SelectionDirection direction) {
    if (!hasSelection()) startSelection();

    for (int i = 0; i < cursorManager.cursors.length; i++) {
      selectionManager.updateSelection(bufferManager, i, direction,
          cursorManager.cursors[i].index, cursorManager.targetCursorIndex);
    }

    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  int get cursorLine => cursorManager.firstCursor().line;
  int get cursorPosition => cursorManager.firstCursor().index;
  List<String> get lines => bufferManager.lines;
  EditorConfig get config => _editorConfig;

  List<String> getLines(int startLine, int endLine) {
    return bufferManager.lines
        .skip(startLine)
        .take(endLine - startLine)
        .toList();
  }

  @override
  String toString() {
    return bufferManager.toString();
  }
}
