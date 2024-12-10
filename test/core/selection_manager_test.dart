import 'package:crystal/core/editor/selection_manager.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

import '../mocks/mock_buffer_manager.dart';

void main() {
  late SelectionManager selectionManager;
  late MockBufferManager mockBufferManager;

  setUp(() {
    mockBufferManager = MockBufferManager();
    selectionManager = SelectionManager();
  });

  group('SelectionManager tests', () {
    group('Basic Selection Tests', () {
      test('should not have a selection initially', () {
        expect(selectionManager.hasSelection(), equals(false));
      });

      test('startSelection should set all properties properly', () {
        selectionManager.startSelection(0, 0);
        expect(selectionManager.startLine, equals(0));
        expect(selectionManager.endLine, equals(0));
        expect(selectionManager.startIndex, equals(0));
        expect(selectionManager.endIndex, equals(0));
        expect(selectionManager.anchor, equals(0));
      });

      test('resetSelection should clear all selection properties', () {
        selectionManager.startSelection(1, 2);
        selectionManager.resetSelection();
        expect(selectionManager.startLine, equals(-1));
        expect(selectionManager.endLine, equals(-1));
        expect(selectionManager.startIndex, equals(-1));
        expect(selectionManager.endIndex, equals(-1));
        expect(selectionManager.anchor, equals(-1));
      });
    });

    group('Selection Range Tests', () {
      test('selectRange should set correct bounds within limits', () {
        mockBufferManager.lines = ['First', 'Second', 'Third'];
        selectionManager.selectRange(mockBufferManager, 0, 2, 1, 3);

        expect(selectionManager.startLine, equals(0));
        expect(selectionManager.startIndex, equals(2));
        expect(selectionManager.endLine, equals(1));
        expect(selectionManager.endIndex, equals(3));
      });

      test('selectRange should clamp values to valid bounds', () {
        mockBufferManager.lines = ['Short'];
        selectionManager.selectRange(mockBufferManager, -1, -1, 100, 100);

        expect(selectionManager.startLine, equals(0));
        expect(selectionManager.startIndex, equals(0));
        expect(selectionManager.endLine, equals(0));
        expect(selectionManager.endIndex, equals(5));
      });
    });

    group('Word Selection Tests', () {
      test('selectWord should select a single word correctly', () {
        mockBufferManager.lines = ['Hello World'];
        final int newIndex =
            selectionManager.selectWord(mockBufferManager, 0, 2);

        expect(selectionManager.startIndex, equals(0));
        expect(selectionManager.endIndex, equals(5));
        expect(newIndex, equals(5));
      });

      test('selectWord should handle word boundaries correctly', () {
        mockBufferManager.lines = ['Hello,World'];
        final int newIndex =
            selectionManager.selectWord(mockBufferManager, 0, 5);
        expect(newIndex, equals(5));
      });
    });

    group('Delete Selection Tests', () {
      test('deleteSelection should handle single line selections', () {
        selectionManager.startSelection(0, 0);
        mockBufferManager.lines = ['Hello World'];
        selectionManager.selection.startIndex = 0;
        selectionManager.selection.endIndex = 5;

        selectionManager.deleteSelection(mockBufferManager, 0);
        verify(mockBufferManager.deleteRange(0, 0, 0, 5)).called(1);
      });

      test('deleteSelection should handle multi-line selections', () {
        mockBufferManager.lines = ['First line', 'Second line', 'Third line'];
        selectionManager.selection.startLine = 0;
        selectionManager.selection.endLine = 2;
        selectionManager.selection.startIndex = 2;
        selectionManager.selection.endIndex = 4;

        selectionManager.deleteSelection(mockBufferManager, 0);
        verify(mockBufferManager.deleteRange(0, 2, 2, 4)).called(1);
      });

      test('deleteSelection should normalize reversed selections', () {
        mockBufferManager.lines = ['Test line'];
        selectionManager.selection.startLine = 0;
        selectionManager.selection.endLine = 0;
        selectionManager.selection.startIndex = 5;
        selectionManager.selection.endIndex = 2;

        selectionManager.deleteSelection(mockBufferManager, 0);
        verify(mockBufferManager.deleteRange(0, 0, 2, 5)).called(1);
      });
    });

    group('Select All Tests', () {
      test('selectAll should select entire buffer content', () {
        mockBufferManager.lines = ['Line 1', 'Line 2', 'Line 3'];
        selectionManager.selectAll(mockBufferManager);

        expect(selectionManager.startLine, equals(0));
        expect(selectionManager.startIndex, equals(0));
        expect(selectionManager.endLine, equals(2));
        expect(selectionManager.endIndex, equals(6));
        expect(selectionManager.anchor, equals(0));
      });

      test('selectAll should handle empty buffer', () {
        mockBufferManager.lines = [];
        selectionManager.selectAll(mockBufferManager);

        expect(selectionManager.startLine, equals(0));
        expect(selectionManager.startIndex, equals(0));
        expect(selectionManager.endLine, equals(0));
        expect(selectionManager.endIndex, equals(0));
      });
    });

    group('Selection Direction Tests', () {
      test('updateSelection should handle forward direction correctly', () {
        mockBufferManager.lines = ['Test Line'];
        selectionManager.startSelection(0, 0);

        selectionManager.updateSelection(
            mockBufferManager, SelectionDirection.forward, 1, 1);

        expect(selectionManager.endIndex, equals(1));
      });

      test('updateSelection should handle backward direction correctly', () {
        mockBufferManager.lines = ['Test Line'];
        selectionManager.startSelection(0, 5);

        selectionManager.updateSelection(
            mockBufferManager, SelectionDirection.backward, 5, 4);

        expect(selectionManager.startIndex, equals(4));
      });
    });

    group('Get Selected Text Tests', () {
      test('getSelectedText should return correct single line selection', () {
        mockBufferManager.lines = ['Hello World'];
        selectionManager.selection.startLine =
            selectionManager.selection.endLine = 0;
        selectionManager.selection.startIndex = 0;
        selectionManager.selection.endIndex = 5;

        expect(selectionManager.getSelectedText(mockBufferManager),
            equals('Hello'));
      });

      test('getSelectedText should return correct multi-line selection', () {
        mockBufferManager.lines = ['First', 'Second', 'Third'];
        selectionManager.selection.startLine = 0;
        selectionManager.selection.endLine = 2;
        selectionManager.selection.startIndex = 2;
        selectionManager.selection.endIndex = 3;

        expect(selectionManager.getSelectedText(mockBufferManager),
            equals('rst\nSecond\nThi'));
      });
    });
  });
}
