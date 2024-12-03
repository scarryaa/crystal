import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:flutter/material.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager bufferManager;
  final CursorManager cursorManager;
  final EditorConfig _editorConfig;

  EditorCore(
      {required this.bufferManager,
      required this.cursorManager,
      required editorConfig})
      : _editorConfig = editorConfig;

  void moveLeft() {
    cursorManager.moveLeft();
    notifyListeners();
  }

  void moveRight() {
    cursorManager.moveRight();
    notifyListeners();
  }

  void moveUp() {
    cursorManager.moveUp();
    notifyListeners();
  }

  void moveDown() {
    cursorManager.moveDown();
    notifyListeners();
  }

  void insertChar(String char) {
    bufferManager.insertCharacter(char);
    notifyListeners();
  }

  void insertLine() {
    bufferManager.insertNewline();
    notifyListeners();
  }

  void delete(int length) {
    bufferManager.delete(length);
    notifyListeners();
  }

  void deleteForwards(int length) {
    bufferManager.deleteForwards(length);
    notifyListeners();
  }

  int get cursorLine => cursorManager.cursorLine;
  int get cursorPosition => cursorManager.cursorIndex;
  List<String> get lines => bufferManager.lines;
  EditorConfig get config => _editorConfig;

  @override
  String toString() {
    return bufferManager.toString();
  }
}
