import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/selection_manager.dart';
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

  void moveTo(int line, int column) {
    cursorManager.moveTo(line, column);
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

  void insertChar(String char) {
    deleteSelectionIfNeeded();
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
    deleteSelectionIfNeeded();
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
    if (deleteSelectionIfNeeded()) return;
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
    if (deleteSelectionIfNeeded()) return;
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
    deleteSelectionIfNeeded();
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

    deleteSelectionIfNeeded();
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
    cursorManager.cursorLine = bufferManager.lines.length - 1;
    cursorManager.cursorIndex = bufferManager.lines[cursorLine].length;
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
    selectionManager.startSelection(-1, -1);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  bool deleteSelectionIfNeeded() {
    if (hasSelection()) {
      final beforeLines = bufferManager.lines.length;
      selectionManager.deleteSelection(bufferManager, cursorPosition);
      clearSelection();

      if (beforeLines != bufferManager.lines.length) {
        forceRefresh?.call();
      }

      onCursorMove?.call(cursorLine, cursorPosition);
      onEdit?.call(bufferManager.toString());
      onSelectionChange?.call(
          selectionManager.anchor,
          selectionManager.startIndex,
          selectionManager.endIndex,
          selectionManager.startLine,
          selectionManager.endLine);
      notifyListeners();
      return true;
    }
    return false;
  }

  void handleSelection(SelectionDirection direction) {
    if (!hasSelection()) startSelection();

    selectionManager.updateSelection(bufferManager, direction,
        cursorManager.cursorIndex, cursorManager.targetCursorIndex);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  int get cursorLine => cursorManager.cursorLine;
  int get cursorPosition => cursorManager.cursorIndex;
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
