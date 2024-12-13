import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../mocks/mock_buffer_manager.dart';
import '../mocks/mock_cursor_manager.mocks.dart';
import '../mocks/mock_editor_config.dart';
import '../mocks/mock_selection.mocks.dart';
import '../mocks/mock_selection_manager.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EditorCore editorCore;
  late MockBufferManager mockBufferManager;
  late MockSelectionManager mockSelectionManager;
  late MockCursorManager mockCursorManager;
  late MockEditorConfig mockEditorConfig;

  setUp(() {
    mockBufferManager = MockBufferManager();
    mockSelectionManager = MockSelectionManager();
    mockCursorManager = MockCursorManager();
    mockEditorConfig = MockEditorConfig();

    editorCore = EditorCore(
      path: '',
      bufferManager: mockBufferManager,
      selectionManager: mockSelectionManager,
      cursorManager: mockCursorManager,
      editorConfig: mockEditorConfig,
    );
  });

  group('Cursor Movement Tests', () {
    test('moveTo should update cursor position and trigger callbacks', () {
      bool callbackCalled = false;
      editorCore.onCursorMove = (line, column) => callbackCalled = true;

      editorCore.moveTo(0, 1, 2);

      verify(mockCursorManager.moveTo(0, 1, 2)).called(1);
      expect(callbackCalled, true);
    });

    test('cursor navigation should update position and trigger callbacks', () {
      final cursor = Cursor(line: 0, index: 0);
      when(mockCursorManager.firstCursor()).thenReturn(cursor);

      editorCore.moveLeft();
      verify(mockCursorManager.moveLeft()).called(1);

      editorCore.moveRight();
      verify(mockCursorManager.moveRight()).called(1);

      editorCore.moveUp();
      verify(mockCursorManager.moveUp()).called(1);

      editorCore.moveDown();
      verify(mockCursorManager.moveDown()).called(1);
    });
  });

  group('Text Modification Tests', () {
    setUp(() {
      final cursor = Cursor(line: 0, index: 0);
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
    });

    test('insertChar should handle selections and notify changes', () {
      bool editCallbackCalled = false;
      editorCore.onEdit = (_) => editCallbackCalled = true;

      editorCore.insertChar('a');

      verify(mockBufferManager.insertCharacter('a')).called(1);
      expect(editCallbackCalled, true);
    });

    test('insertLine should handle selections and notify changes', () {
      editorCore.insertLine();

      verify(mockBufferManager.insertNewline()).called(1);
    });

    test('delete operations should handle selections', () {
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      when(mockSelectionManager.selections).thenReturn([]);

      editorCore.delete(1);
      verify(mockSelectionManager.hasSelection()).called(1);

      editorCore.deleteForwards(1);
      verify(mockSelectionManager.hasSelection()).called(1);
    });
  });

  group('Selection Operations Tests', () {
    test('selection management should work correctly', () {
      final cursor = Cursor(line: 0, index: 0);
      when(mockCursorManager.firstCursor()).thenReturn(cursor);

      editorCore.startSelection();
      verify(mockSelectionManager.startSelection(0, 0)).called(1);

      editorCore.clearSelection();
      verify(mockSelectionManager.clearSelections()).called(1);
    });

    test('handleSelection should update selection state', () {
      final cursor = Cursor(line: 0, index: 0);
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);

      editorCore.handleSelection(SelectionDirection.forward);

      verify(mockSelectionManager.updateSelection(
              mockBufferManager, 0, SelectionDirection.forward, 0, 0))
          .called(1);
    });
  });

  group('Clipboard Operations Tests', () {
    setUp(() {
      when(mockSelectionManager.getSelectedText(mockBufferManager))
          .thenReturn('test text');
    });

    test('copy should handle clipboard operations', () {
      editorCore.copy();
      verify(mockSelectionManager.getSelectedText(mockBufferManager)).called(1);
    });

    test('cut should handle clipboard and text deletion', () {
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      when(mockSelectionManager.selections).thenReturn([]);

      editorCore.cut();

      verify(mockSelectionManager.getSelectedText(mockBufferManager)).called(1);
      verify(mockSelectionManager.hasSelection()).called(1);
    });
  });

  group('Buffer Management Tests', () {
    test('setBuffer should update buffer content', () {
      editorCore.setBuffer('new content');
      verify(mockBufferManager.setText('new content')).called(1);
    });

    test('getLines should return correct line range', () {
      final result = editorCore.getLines(0, 2);
      expect(result, ['first line', 'second line']);
    });
  });

  group('Multi-Selection Tests', () {
    setUp(() {
      final cursor = Cursor(line: 0, index: 0);
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(mockCursorManager.cursors).thenReturn([cursor]);
    });

    test('addCursor should create new cursor and sort', () {
      editorCore.addCursor(1, 5);

      verify(mockCursorManager.addCursor(Cursor(line: 1, index: 5))).called(1);
      verify(mockCursorManager.sortCursors()).called(1);
    });

    test('multiple selections should be deleted in correct order', () {
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      final selection1 = MockSelection()
        ..startLine = 0
        ..startIndex = 0
        ..endLine = 0
        ..endIndex = 5;

      final selection2 = MockSelection()
        ..startLine = 1
        ..startIndex = 0
        ..endLine = 1
        ..endIndex = 10;

      when(mockSelectionManager.selections)
          .thenReturn([selection1, selection2]);

      editorCore.deleteSelectionsIfNeeded();

      verifyInOrder([
        mockSelectionManager.hasSelection(),
        mockSelectionManager.selections,
        mockSelectionManager.clearSelections()
      ]);
    });

    test('handleSelection with multiple cursors should update all selections',
        () {
      final cursors = [Cursor(line: 0, index: 0), Cursor(line: 1, index: 5)];
      when(mockCursorManager.cursors).thenReturn(cursors);
      when(mockSelectionManager.hasSelection()).thenReturn(false);

      editorCore.handleSelection(SelectionDirection.forward);

      verify(mockSelectionManager.startSelection(0, 0)).called(1);
      verify(mockSelectionManager.updateSelection(
              mockBufferManager, 0, SelectionDirection.forward, 0, 0))
          .called(1);
      verify(mockSelectionManager.updateSelection(
              mockBufferManager, 1, SelectionDirection.forward, 5, 0))
          .called(1);
    });

    test('multiple cursors should merge when overlapping', () {
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      final cursors = [Cursor(line: 0, index: 5), Cursor(line: 0, index: 5)];
      when(mockCursorManager.cursors).thenReturn(cursors);

      editorCore.deleteSelectionsIfNeeded();

      verify(mockCursorManager.mergeCursorsIfNeeded()).called(1);
    });

    test(
        'complex selection scenario with multiple cursors should work correctly',
        () {
      mockBufferManager = MockBufferManager()
        ..lines =
            List.generate(100, (int index) => 'Line $index sample content');
      //                                       1  4 5   10 12  17 19   25

      mockSelectionManager = MockSelectionManager();
      mockCursorManager = MockCursorManager();
      mockEditorConfig = MockEditorConfig();

      editorCore = EditorCore(
        path: '',
        bufferManager: mockBufferManager,
        selectionManager: mockSelectionManager,
        cursorManager: mockCursorManager,
        editorConfig: mockEditorConfig,
      );

      when(mockSelectionManager.hasSelection()).thenReturn(true);
      when(mockSelectionManager.selections).thenReturn([
        // Line 1
        // Same line
        MockSelection()
          ..anchor = 5
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 5
          ..endIndex = 10,
        MockSelection()
          ..anchor = 12
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 12
          ..endIndex = 17,
        // Line 2
        // Same line backwards
        MockSelection()
          ..anchor = 10
          ..startLine = 1
          ..endLine = 1
          ..startIndex = 10
          ..endIndex = 5,
        MockSelection()
          ..anchor = 17
          ..startLine = 1
          ..endLine = 1
          ..startIndex = 17
          ..endIndex = 12,
        MockSelection()
          ..anchor = 0
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 0
          ..endIndex = 0,
        MockSelection()
          ..anchor = 0
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 0
          ..endIndex = 0,
        MockSelection()
          ..anchor = 0
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 0
          ..endIndex = 0,
        MockSelection()
          ..anchor = 0
          ..startLine = 0
          ..endLine = 0
          ..startIndex = 0
          ..endIndex = 0,
      ]);

      //editorCore.deleteSelectionsIfNeeded();

      //expect(mockBufferManager.lines[0], 'Line 0  ');
      //expect(mockBufferManager.lines[1], 'Line 1  ');
    });
  });
}
