import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/selection_manager.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:crystal/util/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorCore extends ChangeNotifier {
  final BufferManager bufferManager;
  final SelectionManager selectionManager;
  final CursorManager cursorManager;
  final EditorConfig _editorConfig;
  final String path;

  void Function()? forceRefresh;
  void Function(int line, int column)? onCursorMove;
  void Function(String)? onEdit;
  void Function(int, int, int, int, int)? onSelectionChange;

  // Select by word
  EditorCore({
    required this.bufferManager,
    required this.selectionManager,
    required this.cursorManager,
    required editorConfig,
    this.onCursorMove,
    this.forceRefresh,
    required this.path,
  }) : _editorConfig = editorConfig;

  void moveTo(int index, int line, int column) {
    cursorManager.moveTo(index, line, column);
    onCursorMove?.call(line, column);
    notifyListeners();
  }

  void moveLeft() {
    cursorManager.moveLeft();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveRight() {
    cursorManager.moveRight();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveUp() {
    cursorManager.moveUp();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void moveDown() {
    cursorManager.moveDown();
    onCursorMove?.call(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void addCursor(int line, int index) {
    cursorManager.addCursor(Cursor(line: line, index: index));
    cursorManager.sortCursors();
  }

  void insertChar(String char) {
    deleteSelectionsIfNeeded();
    bufferManager.insertCharacter(char);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void insertLine() {
    deleteSelectionsIfNeeded();
    bufferManager.insertNewline();
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void delete(int length) {
    if (deleteSelectionsIfNeeded()) return;
    bufferManager.delete(length);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void deleteForwards(int length) {
    if (deleteSelectionsIfNeeded()) return;
    bufferManager.deleteForwards(length);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void setBuffer(String content) {
    bufferManager.setText(content);
    onEdit?.call(bufferManager.toString());
  }

  void copy() {
    Clipboard.setData(
        ClipboardData(text: selectionManager.getSelectedText(bufferManager)));
    notifyListeners();
  }

  void cut() {
    Clipboard.setData(
        ClipboardData(text: selectionManager.getSelectedText(bufferManager)));
    deleteSelectionsIfNeeded();
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  Future<void> paste() async {
    final String? clipboardData =
        (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (clipboardData == null) return;

    deleteSelectionsIfNeeded();
    bufferManager.insertString(clipboardData);
    onCursorMove?.call(cursorLine, cursorPosition);
    onEdit?.call(bufferManager.toString());
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void selectAll() {
    selectionManager.selectAll(bufferManager);
    cursorManager.clearCursors();
    cursorManager.moveTo(0, bufferManager.lines.length - 1,
        bufferManager.lines[bufferManager.lines.length - 1].length);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  (int, int, String) getNextWord(String text, int cursorPosition) {
    final characters = text.characters;
    int start = cursorPosition;
    int end = cursorPosition;

    // Skip non-word characters
    while (end < characters.length &&
        !Utils().isWordCharacter(characters.elementAt(end))) {
      end++;
    }
    start = end;

    // Find the end of the next word
    while (end < characters.length &&
        Utils().isWordCharacter(characters.elementAt(end))) {
      end++;
    }

    if (start == end) return (cursorPosition, cursorPosition, '');
    return (start, end, text.substring(start, end));
  }

  (int, int, String) getPreviousWord(String text, int cursorPosition) {
    if (text.isEmpty || cursorPosition <= 0) {
      return (cursorPosition, cursorPosition, '');
    }

    final characters = text.characters;
    final length = characters.length;

    // Ensure cursor position is within bounds
    int start = cursorPosition.clamp(0, length);
    int end = start;

    // Skip non-word characters
    while (start > 0 &&
        start <= length &&
        !Utils().isWordCharacter(characters.elementAt(start - 1))) {
      start--;
    }
    end = start;

    // Find the start of the previous word
    while (
        start > 0 && Utils().isWordCharacter(characters.elementAt(start - 1))) {
      start--;
    }

    if (start == end || start >= length) {
      return (cursorPosition, cursorPosition, '');
    }

    return (start, end, text.substring(start, end));
  }

  bool hasSelectionAtLine(int lineNumber) {
    return selectionManager.hasSelectionAtLine(lineNumber);
  }

  bool hasSelection() {
    return selectionManager.hasSelection();
  }

  bool hasValidSelection() {
    return selectionManager.hasValidSelection();
  }

  void startSelection() {
    selectionManager.startSelection(cursorLine, cursorPosition);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void clearSelection() {
    selectionManager.clearSelections(0);
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  void _sortSelections() {
    for (var layer in selectionManager.layers) {
      layer.sort((a, b) {
        if (b.endLine > a.endLine) return b.endLine.compareTo(a.endLine);

        final int endComparison = a.endIndex.compareTo(b.endIndex);
        return endComparison != 0
            ? endComparison
            : b.startLine.compareTo(a.startLine);
      });
    }
  }

  List<Selection> _deleteSelections() {
    bool selectionDeleted = false;
    _sortSelections();

    // Normalize all selections in all layers
    for (var layer in selectionManager.layers) {
      for (var selection in layer) {
        selection.normalize(bufferManager);
      }
    }

    // Create copies of all selections from all layers
    final List<Selection> selectionsBeforeDeletion = [];
    for (var layer in selectionManager.layers) {
      selectionsBeforeDeletion.addAll(layer.map((selection) => Selection(
            startIndex: selection.startIndex,
            endIndex: selection.endIndex,
            startLine: selection.startLine,
            endLine: selection.endLine,
            anchor: selection.anchor,
            originalDirection: selection.originalDirection,
          )));
    }

    // Process deletions layer by layer
    for (var layer in selectionManager.layers) {
      for (var selection in layer) {
        final beforeLines = bufferManager.lines.length;
        selection.deleteSelection(bufferManager, cursorPosition);

        // Adjust selections in all layers after this deletion
        _adjustSelectionsAfterDeletion(selection);

        _triggerSelectionDeletionCallbacks(
            selection, beforeLines, selectionDeleted);
        selectionDeleted = true;
      }
    }

    return selectionsBeforeDeletion;
  }

  void _adjustSelectionsAfterDeletion(Selection deletedSelection) {
    // Adjust selections in all layers
    for (var layer in selectionManager.layers) {
      final List<Selection> selectionsAfterDeleted = layer.where((s) {
        return deletedSelection.endLine <= s.startLine;
      }).toList();

      // Index adjustment
      for (var selection in selectionsAfterDeleted) {
        if (deletedSelection.endLine == selection.startLine) {
          if (deletedSelection.endLine == deletedSelection.startLine) {
            // Single line deletion
            final int adjustment =
                deletedSelection.endIndex - deletedSelection.startIndex;
            if (selection.startLine == selection.endLine) {
              selection.startIndex -= adjustment;
              selection.endIndex -= adjustment;
            } else {
              selection.startIndex -= adjustment;
            }
          } else {
            // Multi-line deletion
            final int adjustment = deletedSelection.endIndex;
            if (selection.startLine == selection.endLine) {
              selection.startIndex -= adjustment;
              selection.endIndex -= adjustment;
            } else {
              selection.startIndex -= adjustment;
            }
          }
        }
      }

      // Line adjustment
      for (var selection in selectionsAfterDeleted) {
        final int adjustment =
            deletedSelection.endLine - deletedSelection.startLine;
        selection.startLine -= adjustment;
        selection.endLine -= adjustment;
      }
    }
  }

  void _adjustCursors(List<Selection> selectionsBeforeDeletion) {
    // Index adjustment
    for (var cursor in cursorManager.cursors) {
      final List<Selection> selectionsOnTheSameLineAndBeforeCursor =
          selectionsBeforeDeletion.where((s) {
        // On the same line
        if (s.startLine == s.endLine && cursor.line == s.startLine) {
          if (s.endIndex <= cursor.index) {
            return true;
          }
        } else {
          // Multi-line
          if (s.endLine == cursor.line) {
            return true;
          }
        }
        return false;
      }).toList();

      for (var selection in selectionsOnTheSameLineAndBeforeCursor) {
        if (selection.startLine == selection.endLine) {
          // Need to shift cursor index to account for deleted selections
          final adjustment = selection.endIndex - selection.startIndex;
          cursor.index -= adjustment;
        } else {
          final adjustment = selection.endIndex - selection.startIndex;
          cursor.index -= adjustment;
        }
      }
    }

    // Line adjustment
    for (var cursor in cursorManager.cursors) {
      final List<Selection> multiLineSelectionsOnSameLineOrBeforeCursor =
          selectionsBeforeDeletion.where((s) {
        if (s.startLine == s.endLine) return false;

        if (s.endLine <= cursor.line) {
          return true;
        }
        return false;
      }).toList();

      for (var selection in multiLineSelectionsOnSameLineOrBeforeCursor) {
        final adjustment = selection.endLine - selection.startLine;
        cursor.line -= adjustment;
      }
    }

    // Merge cursors if needed
    cursorManager.mergeCursorsIfNeeded();
  }

  void _triggerSelectionDeletionCallbacks(
      Selection selection, int beforeLines, bool selectionDeleted) {
    // Trigger refresh if lines changed
    if (beforeLines != bufferManager.lines.length) {
      forceRefresh?.call();
    }

    // Cursor move callback
    onCursorMove?.call(cursorLine, cursorPosition);

    // Edit callback
    onEdit?.call(bufferManager.toString());

    // Selection change callback
    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
  }

  bool deleteSelectionsIfNeeded() {
    // Check if there are any selections
    if (!selectionManager.hasSelection()) return false;

    final selectionsBeforeDeletion = _deleteSelections();

    cursorManager.sortCursors();
    _adjustCursors(selectionsBeforeDeletion);
    selectionManager.clearSelections(0);
    notifyListeners.call();

    return true;
  }

  void handleSelection(SelectionDirection direction) {
    if (!hasSelection()) startSelection();

    for (int i = 0; i < cursorManager.cursors.length; i++) {
      selectionManager.updateSelection(bufferManager, i, direction,
          cursorManager.cursors[i].index, cursorManager.targetCursorIndex);
    }

    onSelectionChange?.call(
        selectionManager.anchor,
        selectionManager.startIndex,
        selectionManager.endIndex,
        selectionManager.startLine,
        selectionManager.endLine);
    notifyListeners();
  }

  int get cursorLine => cursorManager.firstCursor().line;
  int get cursorPosition => cursorManager.firstCursor().index;
  List<String> get lines => bufferManager.lines;
  EditorConfig get config => _editorConfig;

  List<String> getLines(int startLine, int endLine) {
    return bufferManager.lines
        .skip(startLine)
        .take(endLine - startLine)
        .toList();
  }

  @override
  String toString() {
    return bufferManager.toString();
  }
}
