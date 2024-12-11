import 'package:crystal/core/editor/selection_manager.dart';
import 'package:crystal/models/editor/selection/selection.dart';
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
      test('should not have selections initially', () {
        expect(selectionManager.hasSelection(), equals(false));
      });

      test('startSelection should create new selection', () {
        selectionManager.startSelection(0, 0);
        expect(selectionManager.selections.length, equals(1));
        expect(selectionManager.selections[0].startLine, equals(0));
        expect(selectionManager.selections[0].endLine, equals(0));
        expect(selectionManager.selections[0].startIndex, equals(0));
        expect(selectionManager.selections[0].endIndex, equals(0));
        expect(selectionManager.selections[0].anchor, equals(0));
      });

      test('clearSelections should remove all selections', () {
        selectionManager.startSelection(1, 2);
        selectionManager.clearSelections();
        expect(selectionManager.hasSelection(), equals(false));
      });
    });

    group('Multiple Selections Tests', () {
      test('should handle multiple selections', () {
        selectionManager.startSelection(0, 0);
        selectionManager.startSelection(1, 1);
        expect(selectionManager.hasMultipleSelections(), equals(true));
        expect(selectionManager.selections.length, equals(2));
      });

      test('mergeOverlappingSelections should combine overlapping selections',
          () {
        selectionManager.addSelection(Selection(
            anchor: 0, startLine: 0, endLine: 0, startIndex: 0, endIndex: 5));
        selectionManager.addSelection(Selection(
            anchor: 0, startLine: 0, endLine: 0, startIndex: 3, endIndex: 8));

        selectionManager.mergeOverlappingSelections(mockBufferManager);

        expect(selectionManager.selections.length, equals(1));
        expect(selectionManager.selections[0].startIndex, equals(0));
        expect(selectionManager.selections[0].endIndex, equals(8));
      });
    });

    group('Selection Operations Tests', () {
      test('selectAll should handle non-empty buffer', () {
        selectionManager.selectAll(mockBufferManager);

        expect(selectionManager.selections.length, equals(1));
        expect(selectionManager.selections[0].startLine, equals(0));
        expect(selectionManager.selections[0].endLine, equals(2));
      });

      test('selectWord should select correct word boundaries', () {
        final newIndex = selectionManager.selectWord(mockBufferManager, 0, 2);

        expect(selectionManager.selections[0].startIndex, equals(0));
        expect(selectionManager.selections[0].endIndex, equals(5));
        expect(newIndex, equals(5));
      });

      test('selectLine should select entire line', () {
        selectionManager.selectLine(mockBufferManager, 0, 0);

        expect(selectionManager.selections[0].startIndex, equals(0));
        expect(selectionManager.selections[0].endIndex, equals(0));
        expect(selectionManager.selections[0].startLine, equals(0));
        expect(selectionManager.selections[0].endLine, equals(1));
      });
    });

    group('Selection Range Tests', () {
      test('selectRange should create or update selection', () {
        selectionManager.selectRange(mockBufferManager, 0, 0, 0, 2, 1, 3);

        expect(selectionManager.selections.length, equals(1));
        expect(selectionManager.selections[0].startLine, equals(0));
        expect(selectionManager.selections[0].endLine, equals(1));
        expect(selectionManager.selections[0].startIndex, equals(2));
        expect(selectionManager.selections[0].endIndex, equals(3));
      });
    });

    group('Selection Update Tests', () {
      test('updateSelection should modify selection bounds', () {
        selectionManager.startSelection(0, 0);

        selectionManager.updateSelection(
            mockBufferManager, 0, SelectionDirection.forward, 0, 1);

        expect(selectionManager.selections[0].startIndex, equals(1));
      });
    });
  });
}
