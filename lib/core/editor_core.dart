import 'package:crystal/core/buffer_manager.dart';

class EditorCore {
  final BufferManager _bufferManager;

  EditorCore({required bufferManager}) : _bufferManager = bufferManager;

  void insertChar(String char) {
    _bufferManager.insertCharacter(char);
  }

  List<String> get lines => _bufferManager.lines;

  @override
  String toString() {
    return _bufferManager.toString();
  }
}
