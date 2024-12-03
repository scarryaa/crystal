import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:flutter/material.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager _bufferManager;
  final EditorConfig _editorConfig;

  EditorCore({required bufferManager, required editorConfig})
      : _bufferManager = bufferManager,
        _editorConfig = editorConfig;

  void moveLeft() {
    _bufferManager.moveLeft();
    notifyListeners();
  }

  void moveRight() {
    _bufferManager.moveRight();
    notifyListeners();
  }

  void moveUp() {
    _bufferManager.moveUp();
    notifyListeners();
  }

  void moveDown() {
    _bufferManager.moveDown();
    notifyListeners();
  }

  void insertChar(String char) {
    _bufferManager.insertCharacter(char);
    notifyListeners();
  }

  void insertLine() {
    _bufferManager.insertNewline();
    notifyListeners();
  }

  void delete(int length) {
    _bufferManager.delete(length);
    notifyListeners();
  }

  void deleteForwards(int length) {
    _bufferManager.deleteForwards(length);
    notifyListeners();
  }

  int get cursorLine => _bufferManager.cursorLine;
  int get cursorPosition => _bufferManager.cursorIndex;
  List<String> get lines => _bufferManager.lines;
  EditorConfig get config => _editorConfig;

  @override
  String toString() {
    return _bufferManager.toString();
  }
}
