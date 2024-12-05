import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:flutter_test/flutter_test.dart';

import '../mocks/mock_buffer_manager.dart';

void main() {
  late MockBufferManager bufferManager;
  late CursorManager cursorManager;

  setUp(() {
    bufferManager = MockBufferManager();
    cursorManager = CursorManager(bufferManager);
    bufferManager.cursorManager = cursorManager;
  });

  group('CursorManager Tests', () {
    test('initial cursor position should be 0,0', () {
      expect(cursorManager.cursorLine, equals(0));
      expect(cursorManager.cursorIndex, equals(0));
    });

    test('moveRight should increment cursor index', () {
      cursorManager.moveRight();
      expect(cursorManager.cursorIndex, equals(1));
      expect(cursorManager.cursorLine, equals(0));
    });

    test('moveLeft should decrement cursor index', () {
      cursorManager.moveTo(0, 5); // Move to position first
      cursorManager.moveLeft();
      expect(cursorManager.cursorIndex, equals(4));
      expect(cursorManager.cursorLine, equals(0));
    });

    test('moveDown should increment line number', () {
      cursorManager.moveDown();
      expect(cursorManager.cursorLine, equals(1));
    });

    test('moveUp should decrement line number', () {
      cursorManager.moveTo(1, 0); // Move to second line first
      cursorManager.moveUp();
      expect(cursorManager.cursorLine, equals(0));
    });

    test('moveToLineEnd should move cursor to end of current line', () {
      cursorManager.moveToLineEnd();
      expect(cursorManager.cursorIndex, equals(bufferManager.lines[0].length));
    });

    test('moveToLineStart should move cursor to start of line', () {
      cursorManager.moveTo(0, 5); // Move to position first
      cursorManager.moveToLineStart();
      expect(cursorManager.cursorIndex, equals(0));
    });
  });
}
