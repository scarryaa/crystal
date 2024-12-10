import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../mocks/mock_buffer_manager.dart';
import '../mocks/mock_cursor_manager.mocks.dart';
import '../mocks/mock_editor_config.dart';
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
    test('moveTo should update cursor position and notify listeners', () {
      editorCore.moveTo(0, 1, 2);
      verify(mockCursorManager.moveTo(0, 1, 2)).called(1);
    });

    test('moveLeft should call cursor manager and notify', () {
      editorCore.moveLeft();
      verify(mockCursorManager.moveLeft()).called(1);
    });
  });

  group('Text Modification Tests', () {
    test('insertChar should delete selection if exists and insert character',
        () {
      final cursor = MockCursor();
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(cursor.index).thenReturn(0);

      when(mockSelectionManager.hasSelection()).thenReturn(true);

      editorCore.insertChar('a');

      // Verify selection is deleted before inserting
      verify(mockSelectionManager.hasSelection()).called(1);
      verify(mockSelectionManager.deleteSelection(mockBufferManager, 0))
          .called(1);
      verify(mockBufferManager.insertCharacter('a')).called(1);
    });

    test('delete should handle selection deletion', () {
      // Setup: Simulate an existing selection
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      final cursor = MockCursor();
      when(mockCursorManager.firstCursor()).thenReturn(cursor);
      when(cursor.index).thenReturn(0);

      editorCore.delete(1);

      // Verify selection is deleted
      verify(mockSelectionManager.deleteSelection(mockBufferManager, 0))
          .called(1);
      verifyNever(mockBufferManager.delete(1));
    });
  });

  group('Clipboard Operation Tests', () {
    test('copy should get selected text and set to clipboard', () {
      // Setup: Simulate a selection with text
      when(mockSelectionManager.hasSelection()).thenReturn(true);
      when(mockSelectionManager.getSelectedText(mockBufferManager))
          .thenReturn('test text');

      editorCore.copy();

      verify(mockSelectionManager.getSelectedText(mockBufferManager)).called(1);
    });
  });

  group('Selection Tests', () {
    test('hasSelection should delegate to selection manager', () {
      // Setup
      final selectionManager = MockSelectionManager();
      when(selectionManager.hasSelection()).thenReturn(true);

      final editorCore = EditorCore(
        path: '',
        bufferManager: mockBufferManager,
        selectionManager: selectionManager,
        cursorManager: mockCursorManager,
        editorConfig: mockEditorConfig,
      );

      // Act
      final result = editorCore.hasSelection();

      // Assert
      expect(result, true);
      verify(selectionManager.hasSelection()).called(1);
    });
  });
  test('selectAll should update selection and cursor position', () {
    editorCore.selectAll();
    verify(mockSelectionManager.selectAll(mockBufferManager)).called(1);
  });

  group('Buffer Access Tests', () {
    test('getLines should return correct line range', () {
      final result = editorCore.getLines(0, 2);

      expect(result, ['first line', 'second line']);
    });
  });
}
