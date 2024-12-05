import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:flutter_test/flutter_test.dart';
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

void main() {
  late BufferManager bufferManager;
  late MockCursorManager mockCursorManager;

  setUp(() {
    bufferManager = BufferManager();
    mockCursorManager = MockCursorManager(bufferManager);
    bufferManager.cursorManager = mockCursorManager;
  });

  group('Basic Buffer Operations', () {
    test('initial state', () {
      expect(bufferManager.lineCount, equals(1));
      expect(bufferManager.getLineAt(0), equals(''));
    });

    test('getLineAt throws on invalid index', () {
      expect(() => bufferManager.getLineAt(1), throwsRangeError);
    });
  });

  group('insertString tests', () {
    test('insert single line string', () {
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 0;

      bufferManager.insertString('hello');

      expect(bufferManager.getLineAt(0), equals('hello'));
      expect(mockCursorManager.cursorIndex, equals(5));
    });

    test('insert multi-line string', () {
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 0;

      bufferManager.insertString('hello\nworld');

      expect(bufferManager.lineCount, equals(2));
      expect(bufferManager.getLineAt(0), equals('hello'));
      expect(bufferManager.getLineAt(1), equals('world'));
      expect(mockCursorManager.cursorLine, equals(1));
    });
  });

  group('deleteRange tests', () {
    test('delete within single line', () {
      bufferManager = BufferManager(initialLines: ['hello world']);
      mockCursorManager = MockCursorManager(bufferManager);
      bufferManager.cursorManager = mockCursorManager;

      bufferManager.deleteRange(0, 0, 0, 5);

      expect(bufferManager.getLineAt(0), equals(' world'));
      expect(mockCursorManager.cursorIndex, equals(0));
    });

    test('delete across multiple lines', () {
      bufferManager = BufferManager(initialLines: ['hello', 'world', 'test']);
      mockCursorManager = MockCursorManager(bufferManager);
      bufferManager.cursorManager = mockCursorManager;

      bufferManager.deleteRange(0, 1, 3, 2);

      expect(bufferManager.lineCount, equals(2));
      expect(bufferManager.getLineAt(0), equals('helrld'));
    });

    test('throws on invalid range', () {
      expect(() => bufferManager.deleteRange(-1, 0, 0, 1), throwsArgumentError);
      expect(() => bufferManager.deleteRange(0, 99, 0, 1), throwsArgumentError);
    });
  });

  group('delete tests', () {
    test('delete at start of document should do nothing', () {
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 0;

      bufferManager.delete(1);

      expect(bufferManager.getLineAt(0), equals(''));
    });

    test('delete in middle of line', () {
      bufferManager = BufferManager(initialLines: ['hello']);
      mockCursorManager = MockCursorManager(bufferManager);
      bufferManager.cursorManager = mockCursorManager;
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 3;

      bufferManager.delete(1);

      expect(bufferManager.getLineAt(0), equals('helo'));
      expect(mockCursorManager.cursorIndex, equals(2));
    });
  });

  group('deleteForwards tests', () {
    test('delete forward at end of document should do nothing', () {
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 0;

      bufferManager.deleteForwards(1);

      expect(bufferManager.getLineAt(0), equals(''));
    });

    test('delete forward in middle of text', () {
      bufferManager = BufferManager(initialLines: ['hello']);
      mockCursorManager = MockCursorManager(bufferManager);
      bufferManager.cursorManager = mockCursorManager;
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 2;

      bufferManager.deleteForwards(2);

      expect(bufferManager.getLineAt(0), equals('heo'));
    });
  });

  group('insertCharacter tests', () {
    test('insert character in empty line', () {
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 0;

      bufferManager.insertCharacter('a');

      expect(bufferManager.getLineAt(0), equals('a'));
      expect(mockCursorManager.cursorIndex, equals(1));
    });

    test('insert character in middle of line', () {
      bufferManager = BufferManager(initialLines: ['hello']);
      mockCursorManager = MockCursorManager(bufferManager);
      bufferManager.cursorManager = mockCursorManager;
      mockCursorManager.cursorLine = 0;
      mockCursorManager.cursorIndex = 2;

      bufferManager.insertCharacter('x');

      expect(bufferManager.getLineAt(0), equals('hexllo'));
      expect(mockCursorManager.cursorIndex, equals(3));
    });
  });
}
