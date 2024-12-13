import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter/material.dart';

class SelectionManager extends ChangeNotifier {
  List<Selection> selections = [];
  Selection? anchorSelection;

  int get startLine => anchorSelection?.startLine ?? -1;
  int get endLine => anchorSelection?.endLine ?? -1;
  int get startIndex => anchorSelection?.startIndex ?? -1;
  int get endIndex => anchorSelection?.endIndex ?? -1;
  int get anchor => anchorSelection?.anchor ?? -1;

  void clearSelections() {
    selections.clear();
    notifyListeners();
  }

  void startSelection(int line, int index) {
    selections.add(Selection(
        anchor: index,
        startLine: line,
        endLine: line,
        startIndex: index,
        endIndex: index));
  }

  void selectAll(BufferManager bufferManager) {
    selections.clear();

    if (bufferManager.lines.isEmpty) {
      selections.add(Selection(
          anchor: 0, startLine: 0, endLine: 0, startIndex: 0, endIndex: 0));
      return;
    }

    selections.add(Selection(
        anchor: 0,
        startLine: 0,
        endLine: bufferManager.lines.length - 1,
        startIndex: 0,
        endIndex: bufferManager.lines[bufferManager.lines.length - 1].length));
  }

  String getSelectedText(BufferManager bufferManager) {
    final StringBuffer buffer = StringBuffer();
    for (var selection in selections) {
      if (selection.getSelectedText(bufferManager).isEmpty) {
        buffer.writeln('');
      } else {
        buffer.write(selection.getSelectedText(bufferManager));
      }
    }
    return buffer.toString();
  }

  void addSelection(Selection selection) {
    selections.add(selection);
  }

  void deleteSelection(
      BufferManager bufferManager, int index, int cursorIndex) {
    selections[index].deleteSelection(bufferManager, cursorIndex);
  }

  bool hasSelection() {
    return selections.isNotEmpty;
  }

  bool hasMultipleSelections() {
    return selections.length > 1;
  }

  void updateSelection(BufferManager bufferManager, int index,
      SelectionDirection direction, int currentIndex, int targetIndex) {
    selections[index]
        .updateSelection(bufferManager, direction, currentIndex, targetIndex);
  }

  int selectWord(BufferManager bufferManager, int cursorLine, int cursorIndex) {
    selections.clear();
    selections.add(Selection(
        anchor: 0,
        startLine: cursorLine,
        endLine: cursorLine,
        startIndex: 0,
        endIndex: 0));
    return selections[0].selectWord(bufferManager, cursorLine, cursorIndex);
  }

  void selectLine(BufferManager bufferManager, int index, int cursorLine) {
    selections.clear();
    selections.add(Selection(
        anchor: 0,
        startLine: cursorLine,
        endLine: cursorLine,
        startIndex: 0,
        endIndex: 0));
    selections[index].selectLine(bufferManager, cursorLine);
  }

  void selectRange(BufferManager bufferManager, int anchor, int index,
      int startLine, int startIndex, int endLine, int endIndex) {
    final Selection currentSelection =
        getSelectionAt(anchor, startLine, startIndex, endLine, endIndex);
    currentSelection.selectRange(
        bufferManager, startLine, startIndex, endLine, endIndex);

    if (!selections.contains(currentSelection)) {
      selections.add(currentSelection);
    }
  }

  (bool, Selection) isWithinSelection(
      BufferManager bufferManager, int line, int index) {
    final Selection foundSelection = selections.firstWhere((s) {
      if (line < s.startLine || line > s.endLine) return false;
      if (line == s.startLine && line == s.endLine) {
        return index >= s.startIndex && index <= s.endIndex;
      }
      if (line == s.startLine) {
        return index >= s.startIndex;
      }
      if (line == s.endLine) return index <= s.endIndex;
      return true;
    }, orElse: () => Selection());
    return (!foundSelection.isNullSelection(), foundSelection);
  }

  void removeSelection(Selection selection) {
    selections.remove(selection);
    notifyListeners();
  }

  void mergeOverlappingSelections(BufferManager bufferManager) {
    if (selections.isEmpty) return;

    // Normalize selections
    for (final selection in selections) {
      selection.normalize(bufferManager);
    }

    // Get the last (current) selection
    final activeSelection = selections.last;

    // Sort by start position
    selections.sort((a, b) {
      if (a.startLine != b.startLine) return a.startLine.compareTo(b.startLine);
      return a.startIndex.compareTo(b.startIndex);
    });

    final List<Selection> mergedSelections = [selections.first];

    for (var i = 1; i < selections.length; i++) {
      final current = selections[i];
      final last = mergedSelections.last;

      if (_selectionsOverlap(last, current)) {
        last.originalDirection = activeSelection.originalDirection;

        if (current.endLine > last.endLine) {
          last.endLine = current.endLine;
          last.endIndex = current.endIndex;
        } else if (current.endLine == last.endLine) {
          last.endIndex = max(last.endIndex, current.endIndex);
        }
      } else {
        mergedSelections.add(current);
      }
    }

    selections
      ..clear()
      ..addAll(mergedSelections);
    notifyListeners();
  }

  bool _selectionsOverlap(Selection a, Selection b) {
    if (a.endLine < b.startLine) return false;
    if (a.startLine > b.endLine) return false;
    if (a.endLine == b.startLine) {
      return a.endIndex >= b.startIndex;
    }
    return true;
  }

  Selection getSelectionAt(
      int anchor, int startLine, int startIndex, int endLine, int endIndex) {
    final Selection nullSelection = Selection(
        anchor: -1, startLine: -1, endLine: -1, startIndex: -1, endIndex: -1);
    final foundSelection = selections.firstWhere(
        (s) =>
            ((s.startIndex == startIndex && s.startLine == startLine) ||
                s.endIndex == endIndex && s.endLine == endLine) &&
            (s.anchor == anchor || s.endIndex == startIndex),
        orElse: () => nullSelection);
    return foundSelection;
  }
}
