import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter/material.dart';

class SelectionManager extends ChangeNotifier {
  final List<List<Selection>> layers = [[]];
  Selection? anchorSelection;

  int get startLine => anchorSelection?.startLine ?? -1;
  int get endLine => anchorSelection?.endLine ?? -1;
  int get startIndex => anchorSelection?.startIndex ?? -1;
  int get endIndex => anchorSelection?.endIndex ?? -1;
  int get anchor => anchorSelection?.anchor ?? -1;

  void clearSelections(int layerNumber) {
    if (layerNumber < layers.length) {
      layers[layerNumber].clear();
      notifyListeners();
    }
  }

  void startSelection(int line, int index, {int layerIndex = 0}) {
    while (layers.length <= layerIndex) {
      layers.add([]);
    }

    layers[layerIndex].add(Selection(
        anchor: index,
        startLine: line,
        endLine: line,
        startIndex: index,
        endIndex: index));
    notifyListeners();
  }

  void selectAll(BufferManager bufferManager) {
    layers[0].clear();

    if (bufferManager.lines.isEmpty) {
      layers[0].add(Selection(
          anchor: 0, startLine: 0, endLine: 0, startIndex: 0, endIndex: 0));
      return;
    }

    layers[0].add(Selection(
        anchor: 0,
        startLine: 0,
        endLine: bufferManager.lines.length - 1,
        startIndex: 0,
        endIndex: bufferManager.lines[bufferManager.lines.length - 1].length));
    notifyListeners();
  }

  String getSelectedText(BufferManager bufferManager) {
    final StringBuffer buffer = StringBuffer();
    for (var selection in layers[0]) {
      if (selection.getSelectedText(bufferManager).isEmpty) {
        buffer.writeln('');
      } else {
        buffer.write(selection.getSelectedText(bufferManager));
      }
    }
    return buffer.toString();
  }

  void addSelection(Selection selection, {required int layer}) {
    while (layers.length <= layer) {
      layers.add([]);
    }
    layers[layer].add(selection);
    notifyListeners();
  }

  void deleteSelection(
      BufferManager bufferManager, int index, int cursorIndex) {
    if (layers[0].isNotEmpty && index < layers[0].length) {
      layers[0][index].deleteSelection(bufferManager, cursorIndex);
      notifyListeners();
    }
  }

  bool hasSelectionAtLine(int lineNumber) {
    return layers[0]
        .where((s) =>
            (s.startLine == lineNumber || s.endLine == lineNumber) &&
            s.startIndex != s.endIndex)
        .isNotEmpty;
  }

  bool hasSelection() {
    return layers[0].isNotEmpty;
  }

  bool hasValidSelection() {
    return layers[0].isNotEmpty &&
        layers[0].every((s) => s.startIndex != s.endIndex);
  }

  bool hasMultipleSelections() {
    return layers[0].length > 1;
  }

  void updateSelection(BufferManager bufferManager, int index,
      SelectionDirection direction, int currentIndex, int targetIndex) {
    if (layers[0].isNotEmpty && index < layers[0].length) {
      layers[0][index]
          .updateSelection(bufferManager, direction, currentIndex, targetIndex);
      notifyListeners();
    }
  }

  void mergeAllLayersToFirst(BufferManager bufferManager) {
    if (layers.length <= 1) return;

    for (int i = 1; i < layers.length; i++) {
      layers[0].addAll(layers[i]);
    }

    // Keep only the first layer
    layers.removeRange(1, layers.length);

    // Merge overlapping selections within the first layer
    mergeOverlappingSelections(bufferManager, layer: 0);
    notifyListeners();
  }

  void mergeOverlappingSelections(BufferManager bufferManager,
      {required int layer}) {
    if (layers[layer].isEmpty) return;

    // Normalize selections
    for (final selection in layers[layer]) {
      selection.normalize(bufferManager);
    }

    final activeSelection = layers[layer].last;
    layers[layer].sort((a, b) {
      if (a.startLine != b.startLine) return a.startLine.compareTo(b.startLine);
      return a.startIndex.compareTo(b.startIndex);
    });

    final List<Selection> mergedSelections = [layers[layer].first];

    for (var i = 1; i < layers[layer].length; i++) {
      final current = layers[layer][i];
      final last = mergedSelections.last;

      if (_selectionsOverlap(
          bufferManager.getLineLength(last.endLine), last, current)) {
        last.originalDirection = activeSelection.originalDirection;
        if (current.endLine > last.endLine) {
          last.endLine = current.endLine;
          last.endIndex = current.endIndex;
        } else if (current.endLine == last.endLine) {
          last.endIndex = max(last.endIndex, current.endIndex);
        }

        if (current.originalCursor != null) {
          last.originalCursor = current.originalCursor;
        }
      } else {
        mergedSelections.add(current);
      }
    }

    layers[layer]
      ..clear()
      ..addAll(mergedSelections);
    notifyListeners();
  }

  bool _selectionsOverlap(int aLineLength, Selection a, Selection b) {
    if (a.endLine < b.startLine - 1) return false;
    if (a.startLine > b.endLine + 1) return false;

    if (a.endLine == b.startLine - 1 || a.startLine == b.endLine + 1) {
      if (aLineLength == a.endIndex && b.startIndex == 0) {
        return true;
      }
      return false;
    }
    if (a.endLine == b.startLine) {
      return a.endIndex >= b.startIndex;
    }
    return true;
  }

  Selection getSelectionAtLineAndIndex(int line, int index,
      {required int layer}) {
    final Selection nullSelection = Selection(
        anchor: -1, startLine: -1, endLine: -1, startIndex: -1, endIndex: -1);

    return layers[layer].firstWhere(
        (s) => s.startLine <= line && s.startIndex <= index,
        orElse: () => nullSelection);
  }

  Selection getSelectionAt(
      int anchor, int startLine, int startIndex, int endLine, int endIndex,
      {required int layer}) {
    final Selection nullSelection = Selection(
        anchor: -1, startLine: -1, endLine: -1, startIndex: -1, endIndex: -1);

    return layers[layer].firstWhere(
        (s) =>
            ((s.startIndex == startIndex && s.startLine == startLine) ||
                s.endIndex == endIndex && s.endLine == endLine) &&
            (s.anchor == anchor || s.endIndex == startIndex),
        orElse: () => nullSelection);
  }

  void removeSelection(Selection selection) {
    layers[0].remove(selection);
    notifyListeners();
  }

  (bool, Selection) isWithinSelection(
      BufferManager bufferManager, int line, int index,
      {required int layer}) {
    final Selection foundSelection = layers[layer].firstWhere((s) {
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

  int selectWord(BufferManager bufferManager, int cursorLine, int cursorIndex,
      {bool clearSelections = false, required int layer}) {
    if (clearSelections) {
      layers[layer].clear();
    }

    layers[layer].add(Selection(
        anchor: cursorIndex,
        startLine: cursorLine,
        endLine: cursorLine,
        startIndex: cursorIndex,
        endIndex: cursorIndex));
    return layers[layer][0].selectWord(bufferManager, cursorLine, cursorIndex);
  }

  void selectLine(BufferManager bufferManager, int index, int cursorLine,
      {bool clearSelections = false, required int layer}) {
    if (clearSelections) {
      layers[layer].clear();
    }

    layers[layer].add(Selection(
      anchor: 0,
      startLine: cursorLine,
      endLine: cursorLine,
      startIndex: 0,
      endIndex: bufferManager.getLineLength(cursorLine),
    ));
  }

  void selectRange(BufferManager bufferManager, int anchor, int index,
      int startLine, int startIndex, int endLine, int endIndex,
      {SelectionDirection? direction, required int layer}) {
    final Selection currentSelection = getSelectionAt(
        anchor, startLine, startIndex, endLine, endIndex,
        layer: layer);
    currentSelection.selectRange(
        bufferManager, startLine, startIndex, endLine, endIndex);
    if (direction != null) {
      currentSelection.originalDirection = direction;
    }

    if (!layers[layer].contains(currentSelection)) {
      layers[layer].add(currentSelection);
    }
  }
}
