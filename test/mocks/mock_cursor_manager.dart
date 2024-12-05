import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:mockito/mockito.dart';

class MockCursorManager extends Mock implements CursorManager {
  @override
  int cursorLine = 0;
  @override
  int cursorIndex = 0;
  @override
  int targetCursorIndex = 0;
  final BufferManager bufferManager;

  MockCursorManager(this.bufferManager) : super();
}
