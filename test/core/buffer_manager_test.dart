import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks/mock_cursor_manager.mocks.dart';

void main() {
  late BufferManager bufferManager;
  late MockCursorManager mockCursorManager;

  setUp(() {
    bufferManager = BufferManager();
    mockCursorManager = MockCursorManager();
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
      bufferManager = BufferManager(initialLines: ['']);

      final mockCursor = MockCursor();
      when(mockCursor.line).thenReturn(0);
      when(mockCursor.index).thenReturn(0);

      mockCursorManager = MockCursorManager();
      when(mockCursorManager.firstCursor()).thenReturn(mockCursor);
      when(mockCursorManager.cursors).thenReturn([mockCursor]);

      bufferManager.cursorManager = mockCursorManager;

      bufferManager.insertString('hello');

      expect(bufferManager.getLineAt(0), equals('hello'));
      verify(mockCursor.index = 5).called(1);
    });

    test('insert multi-line string', () {
      final cursor = MockCursor();

      // Set up mock cursor manager
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
      when(cursor.line).thenReturn(0);
      when(cursor.index).thenReturn(0);

      // Create buffer manager with mock cursor manager
      bufferManager = BufferManager(cursorManager: mockCursorManager);

      // Insert multi-line string
      bufferManager.insertString('hello\nworld');

      expect(bufferManager.lineCount, equals(2));
      expect(bufferManager.getLineAt(0), equals('hello'));
      expect(bufferManager.getLineAt(1), equals('world'));

      // Verify cursor position update
      verify(cursor.line = 1).called(1);
      verify(cursor.index = 5).called(1);
    });
  });

  group('deleteRange tests', () {
    test('delete within single line', () {
      final mockCursor = MockCursor();
      mockCursorManager = MockCursorManager();

      when(mockCursorManager.firstCursor()).thenReturn(mockCursor);

      bufferManager = BufferManager(initialLines: ['hello world']);
      bufferManager.cursorManager = mockCursorManager;

      bufferManager.deleteRange(0, 0, 0, 5);

      expect(bufferManager.getLineAt(0), equals(' world'));
      expect(mockCursorManager.firstCursor().index, equals(0));
    });

    test('delete across multiple lines', () {
      bufferManager = BufferManager(initialLines: ['hello', 'world', 'test']);
      mockCursorManager = MockCursorManager();
      bufferManager.cursorManager = mockCursorManager;

      final mockCursor = MockCursor();
      when(mockCursorManager.firstCursor()).thenReturn(mockCursor);

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
      bufferManager.delete(1);

      expect(bufferManager.getLineAt(0), equals(''));
    });

    test('delete in middle of line', () {
      final cursor = MockCursor();

      // Set up mock cursor behavior
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
      when(cursor.line).thenReturn(0);
      when(cursor.index).thenReturn(3);

      bufferManager = BufferManager(
          initialLines: ['hello'], cursorManager: mockCursorManager);

      bufferManager.delete(1);

      expect(bufferManager.getLineAt(0), equals('helo'));
    });
  });

  group('deleteForwards tests', () {
    test('delete forward at end of document should do nothing', () {
      bufferManager.deleteForwards(1);

      expect(bufferManager.getLineAt(0), equals(''));
    });

    test('delete forward in middle of text', () {
      final cursor = MockCursor();

      // Set up mock cursor behavior
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
      when(cursor.line).thenReturn(0);
      when(cursor.index).thenReturn(2);

      // Create buffer manager with initial text
      bufferManager = BufferManager(
          initialLines: ['hello'], cursorManager: mockCursorManager);

      bufferManager.deleteForwards(1);

      expect(bufferManager.getLineAt(0), equals('helo'));
      verify(mockCursorManager.mergeCursorsIfNeeded()).called(1);
    });
  });

  group('insertCharacter tests', () {
    test('insert character in empty line', () {
      final cursor = MockCursor();

      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
      when(cursor.line).thenReturn(0);
      when(cursor.index).thenReturn(0);

      bufferManager.insertCharacter('a');

      expect(bufferManager.getLineAt(0), equals('a'));
    });

    test('insert character in middle of line', () {
      final cursor = MockCursor();

      bufferManager = BufferManager(
          initialLines: ['hello'], cursorManager: mockCursorManager);

      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
      when(cursor.line).thenReturn(0);
      when(cursor.index).thenReturn(2);

      bufferManager.insertCharacter('x');

      expect(bufferManager.getLineAt(0), equals('hexllo'));
    });
  });
}
