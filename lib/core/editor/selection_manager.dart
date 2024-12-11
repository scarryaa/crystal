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
    // TODO
    return '';
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

  void mergeOverlappingSelections(BufferManager bufferManager) {
    for (var selection in selections) {
      selection.normalize(bufferManager);
    }

    selections.sort((a, b) => a.startLine.compareTo(b.startLine));
    final List<Selection> mergedSelections = [];

    for (var selection in selections) {
      // If mergedSelections is empty or current selection doesn't overlap with last merged selection
      if (mergedSelections.isEmpty ||
          ((selection.startLine > mergedSelections.last.endLine) ||
              (selection.startLine == mergedSelections.last.endLine &&
                  selection.startIndex > mergedSelections.last.endIndex) ||
              selection.endLine <= mergedSelections.last.startLine &&
                  selection.endIndex < mergedSelections.last.startIndex)) {
        mergedSelections.add(selection);
      } else {
        // Merge overlapping selections
        final lastMerged = mergedSelections.last;

        if (lastMerged.endLine <= selection.endLine &&
            lastMerged.endIndex < selection.endIndex) {
          lastMerged.endIndex = selection.endIndex;
        }
        if (lastMerged.startLine >= selection.startLine &&
            lastMerged.startIndex > selection.startIndex) {
          lastMerged.startIndex = selection.startIndex;
        }
        lastMerged.endLine = max(lastMerged.endLine, selection.endLine);
        lastMerged.startLine = min(lastMerged.startLine, selection.startLine);
      }
    }

    selections.clear();
    selections.addAll(mergedSelections);

    notifyListeners();
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
