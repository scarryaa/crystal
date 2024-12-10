import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:mockito/mockito.dart';

class MockBufferManager extends Mock implements BufferManager {
  List<String> _lines = ['first line', 'second line', 'third line'];

  @override
  List<String> get lines => _lines;

  @override
  set lines(List<String> lines) => _lines = lines;

  @override
  String getLineAt(int index) => _lines[index];

  @override
  int get lineCount => _lines.length;

  @override
  String get currentLine => _lines[cursorManager.firstCursor().line];

  @override
  late CursorManager cursorManager;
}
