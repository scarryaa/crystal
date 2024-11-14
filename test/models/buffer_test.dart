import 'package:crystal/models/editor/buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Buffer buffer;

  setUp(() {
    buffer = Buffer();
  });

  group('Buffer Initialization', () {
    test('should initialize with default values', () {
      expect(buffer.version, equals(1));
      expect(buffer.lines, equals(['']));
      expect(buffer.isDirty, isFalse);
      expect(buffer.lineCount, equals(1));
      expect(buffer.isEmpty, isFalse);
    });
  });

  group('Content Management', () {
    test('setContent should properly split content into lines', () {
      buffer.setContent('Line 1\nLine 2\nLine 3');
      expect(buffer.lineCount, equals(3));
      expect(buffer.lines, equals(['Line 1', 'Line 2', 'Line 3']));
      expect(buffer.version, equals(2));
      expect(buffer.isDirty, isFalse);
    });

    test('setContent with empty string should set default empty line', () {
      buffer.setContent('');
      expect(buffer.lines, equals(['']));
      expect(buffer.lineCount, equals(1));
    });

    test('getLine should return correct line content', () {
      buffer.setContent('Line 1\nLine 2');
      expect(buffer.getLine(0), equals('Line 1'));
      expect(buffer.getLine(1), equals('Line 2'));
    });

    test('getLineLength should return correct line length', () {
      buffer.setContent('Line 1\nLonger Line 2');
      expect(buffer.getLineLength(0), equals(6));
      expect(buffer.getLineLength(1), equals(13));
    });
  });

  group('Line Operations', () {
    test('insertLine should add new line at specified position', () {
      buffer.setContent('Line 1\nLine 3');
      buffer.insertLine(1, content: 'Line 2');
      expect(buffer.lineCount, equals(3));
      expect(buffer.lines, equals(['Line 1', 'Line 2', 'Line 3']));
      expect(buffer.version, equals(3));
      expect(buffer.isDirty, isTrue);
    });

    test('removeLine should remove line at specified position', () {
      buffer.setContent('Line 1\nLine 2\nLine 3');
      buffer.removeLine(1);
      expect(buffer.lineCount, equals(2));
      expect(buffer.lines, equals(['Line 1', 'Line 3']));
      expect(buffer.isDirty, isTrue);
    });

    test('setLine should update line content', () {
      buffer.setContent('Line 1\nOld Line\nLine 3');
      buffer.setLine(1, 'New Line');
      expect(buffer.getLine(1), equals('New Line'));
      expect(buffer.isDirty, isTrue);
    });
  });

  group('Text Replacement', () {
    test('replace should correctly modify part of a line', () {
      buffer.setContent('Hello world');
      buffer.replace(0, 6, 5, 'Flutter');
      expect(buffer.getLine(0), equals('Hello Flutter'));
    });

    test('replace should work with empty replacement', () {
      buffer.setContent('Hello world');
      buffer.replace(0, 5, 1, '');
      expect(buffer.getLine(0), equals('Helloworld'));
    });
  });

  group('Version Control', () {
    test('incrementVersion should increase version number', () {
      int initialVersion = buffer.version;
      buffer.incrementVersion();
      expect(buffer.version, equals(initialVersion + 1));
    });

    test('isDirty should track changes correctly', () {
      buffer.setContent('Initial content');
      expect(buffer.isDirty, isFalse);

      buffer.setLine(0, 'Modified content');
      expect(buffer.isDirty, isTrue);

      buffer.setContent('Modified content');
      expect(buffer.isDirty, isFalse);
    });
  });

  group('Edge Cases', () {
    test('should handle multi-line content with empty lines', () {
      buffer.setContent('Line 1\n\nLine 3');
      expect(buffer.lineCount, equals(3));
      expect(buffer.lines, equals(['Line 1', '', 'Line 3']));
    });

    test('should throw RangeError when accessing invalid line numbers', () {
      buffer.setContent('Single line');
      expect(() => buffer.getLine(1), throwsRangeError);
      expect(() => buffer.removeLine(-1), throwsRangeError);
    });
  });

  test('should handle large content', () {
    String largeContent =
        List.generate(10000, (index) => 'Line $index').join('\n');
    buffer.setContent(largeContent);
    expect(buffer.lineCount, equals(10000));
    expect(buffer.getLine(9999), equals('Line 9999'));
  });

  test('should handle folding operations on invalid ranges', () {
    buffer.setContent('Line 1\nLine 2\nLine 3');
    buffer.foldLines(0, 3); // End line out of range
    expect(buffer.foldedRanges, isEmpty);
    buffer.foldLines(2, 1); // Start line greater than end line
    expect(buffer.foldedRanges, isEmpty);
  });

  group('Folding Operations', () {
    test('should fold and unfold lines correctly', () {
      buffer.setContent('Line 1\nLine 2\nLine 3\nLine 4\nLine 5');
      buffer.foldLines(1, 3);
      expect(buffer.isLineFolded(1), isTrue);
      expect(buffer.getFoldedRange(1), equals(3));
      expect(buffer.content, equals('Line 1\nLine 2\nLine 5'));

      buffer.unfoldLines(1);
      expect(buffer.isLineFolded(1), isFalse);
      expect(buffer.content, equals('Line 1\nLine 2\nLine 3\nLine 4\nLine 5'));
    });

    test('should handle nested folds', () {
      buffer.setContent('Line 1\nLine 2\nLine 3\nLine 4\nLine 5');
      buffer.foldLines(0, 4);
      buffer.foldLines(1, 3);
      expect(buffer.isLineFolded(0), isTrue);
      expect(buffer.isLineFolded(1), isTrue);
      expect(buffer.content, equals('Line 1'));
    });
  });
}
