import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
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
      expect(cursorManager.cursors.length, 1);
      expect(cursorManager.cursors.first, Cursor(line: 0, index: 0));
    });

    test('firstCursor should create a cursor if empty', () {
      cursorManager.cursors = [];
      cursorManager.firstCursor();
      expect(cursorManager.cursors.length, 1);
    });

    test('clearCursors should clear all cursors besides the anchor cursor', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 0),
        Cursor(line: 2, index: 5),
        Cursor(line: 5, index: 2)
      ];
      cursorManager.clearCursors();
      expect(cursorManager.cursors.length, 1);
    });

    test('addCursor should add a cursor', () {
      cursorManager.cursors = [];
      cursorManager.addCursor(Cursor(line: 0, index: 1));

      expect(cursorManager.cursors.length, 1);
      expect(cursorManager.cursors.first, Cursor(line: 0, index: 1));
    });

    test('removeCursor should remove a cursor', () {
      cursorManager.cursors = [Cursor(line: 0, index: 1)];
      cursorManager.removeCursor(Cursor(line: 0, index: 1));

      expect(cursorManager.cursors.length, 0);
    });

    test('removeCursorAt should remove a cursor by index', () {
      cursorManager.cursors = [Cursor(line: 0, index: 1)];
      cursorManager.removeCursorAt(0);

      expect(cursorManager.cursors.length, 0);
    });

    test('moveTo should move a cursor to a new location', () {
      cursorManager.cursors = [Cursor(line: 0, index: 1)];
      cursorManager.moveTo(0, 2, 1);

      expect(cursorManager.cursors.first, Cursor(line: 2, index: 1));
    });

    test('moveTo should merge overlapping cursors if needed', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 1),
        Cursor(line: 2, index: 1)
      ];
      cursorManager.moveTo(0, 2, 1);

      expect(cursorManager.cursors.first, Cursor(line: 2, index: 1));
      expect(cursorManager.cursors.length, 1);
    });

    test('sortCursors should sort cursors', () {
      cursorManager.cursors = [
        Cursor(line: 3, index: 0),
        Cursor(line: 0, index: 0),
      ];

      cursorManager.sortCursors();
      expect(cursorManager.cursors.first, Cursor(line: 0, index: 0));
      expect(cursorManager.cursors[1], Cursor(line: 3, index: 0));
    });

    test('sortCursors with reverse = true should sort cursors in reverse', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 0),
        Cursor(line: 3, index: 0),
      ];

      cursorManager.sortCursors(reverse: true);
      expect(cursorManager.cursors.first, Cursor(line: 3, index: 0));
      expect(cursorManager.cursors[1], Cursor(line: 0, index: 0));
    });

    test('moveRight should increment all cursor indexes', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 0),
        Cursor(line: 1, index: 0)
      ];
      cursorManager.moveRight();

      expect(cursorManager.cursors[0].line, 0);
      expect(cursorManager.cursors[0].index, 1);
      expect(cursorManager.cursors[1].line, 1);
      expect(cursorManager.cursors[1].line, 1);
    });

    test('moveLeft should decrement all cursor indexes', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 2),
        Cursor(line: 1, index: 2)
      ];
      cursorManager.moveLeft();

      expect(cursorManager.cursors[0].line, 0);
      expect(cursorManager.cursors[0].index, 1);
      expect(cursorManager.cursors[1].line, 1);
      expect(cursorManager.cursors[1].line, 1);
    });

    test('moveDown should increment all line numbers', () {
      cursorManager.cursors = [
        Cursor(line: 0, index: 2),
        Cursor(line: 1, index: 2)
      ];
      cursorManager.moveDown();

      expect(cursorManager.cursors[0].line, 1);
      expect(cursorManager.cursors[1].line, 2);
    });

    test('moveUp should decrement all line numbers', () {
      cursorManager.cursors = [
        Cursor(line: 1, index: 2),
        Cursor(line: 2, index: 2)
      ];
      cursorManager.moveUp();

      expect(cursorManager.cursors[0].line, 0);
      expect(cursorManager.cursors[1].line, 1);
    });

    test('moveToLineEnd should move all cursors to end of their current lines',
        () {
      final bufferManager = BufferManager(initialLines: [
        'line0', // length 5
        'line1', // length 5
        'line2' // length 5
      ]);

      final cursorManager = CursorManager(bufferManager);

      cursorManager.cursors = [
        Cursor(line: 1, index: 2),
        Cursor(line: 2, index: 2)
      ];

      cursorManager.moveToLineEnd();

      expect(cursorManager.cursors[0].index, equals(5));
      expect(cursorManager.cursors[1].index, equals(5));
    });

    test(
        'moveToLineStart should move all cursors to start of their current lines',
        () {
      cursorManager.cursors = [
        Cursor(line: 1, index: 2),
        Cursor(line: 2, index: 2)
      ];

      cursorManager.moveToLineStart();
      expect(cursorManager.cursors[0].index, equals(0));
      expect(cursorManager.cursors[1].index, equals(0));
    });
  });
}
