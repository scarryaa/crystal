import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:flutter/material.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager _bufferManager;
  final EditorConfig _editorConfig;

  EditorCore({required bufferManager, required editorConfig})
      : _bufferManager = bufferManager,
        _editorConfig = editorConfig;

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

  int get cursorLine => _bufferManager.cursorLine;
  int get cursorPosition => _bufferManager.cursorPosition;
  List<String> get lines => _bufferManager.lines;
  EditorConfig get config => _editorConfig;

  @override
  String toString() {
    return _bufferManager.toString();
  }
}
