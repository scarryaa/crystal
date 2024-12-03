import 'package:crystal/core/buffer_manager.dart';
import 'package:flutter/material.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager _bufferManager;

  EditorCore({required bufferManager}) : _bufferManager = bufferManager;

  void insertChar(String char) {
    _bufferManager.insertCharacter(char);
    notifyListeners();
  }

  List<String> get lines => _bufferManager.lines;

  @override
  String toString() {
    return _bufferManager.toString();
  }
}
