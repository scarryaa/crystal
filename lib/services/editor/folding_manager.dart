import 'package:crystal/models/editor/buffer.dart';
import 'package:flutter/material.dart';

class FoldingManager extends ChangeNotifier {
  final Map<int, int> _foldedRegions = {};
  final Buffer buffer;

  FoldingManager(this.buffer);

  bool isFolded(int line) => _foldedRegions.containsKey(line);

  Map<int, int> get foldedRegions => Map.from(_foldedRegions);

  void toggleFold(int startLine, int endLine) {
    if (isFolded(startLine)) {
      // When unfolding, also unfold any nested folds within this region
      final nestedFolds = _getNestedFolds(startLine, endLine);
      for (final nestedStart in nestedFolds) {
        buffer.unfoldLines(nestedStart);
        _foldedRegions.remove(nestedStart);
      }

      buffer.unfoldLines(startLine);
      _foldedRegions.remove(startLine);
    } else {
      // When folding, first unfold any existing folds within this region
      final existingFolds = _getExistingFoldsInRange(startLine, endLine);
      for (final foldStart in existingFolds) {
        buffer.unfoldLines(foldStart);
        _foldedRegions.remove(foldStart);
      }

      buffer.foldLines(startLine, endLine);
      _foldedRegions[startLine] = endLine;
    }
    notifyListeners();
  }

  List<int> _getNestedFolds(int startLine, int endLine) {
    return _foldedRegions.keys
        .where((line) => line > startLine && line <= endLine)
        .toList();
  }

  List<int> _getExistingFoldsInRange(int startLine, int endLine) {
    return _foldedRegions.keys
        .where((line) => line >= startLine && line <= endLine)
        .toList();
  }

  List<int> getVisibleLines(List<String> lines) {
    final visibleLines = <int>[];
    final sortedFolds = _getSortedFoldRegions();

    for (int i = 0; i < lines.length; i++) {
      if (!_isLineHiddenInFolds(i, sortedFolds)) {
        visibleLines.add(i);
      }
    }

    return visibleLines;
  }

  List<MapEntry<int, int>> _getSortedFoldRegions() {
    final folds = _foldedRegions.entries.toList();
    folds.sort((a, b) => a.key.compareTo(b.key));
    return folds;
  }

  bool isLineHidden(int line) {
    return _isLineHiddenInFolds(line, _getSortedFoldRegions());
  }

  bool _isLineHiddenInFolds(int line, List<MapEntry<int, int>> sortedFolds) {
    for (final fold in sortedFolds) {
      if (line > fold.key && line <= fold.value) {
        // Check if this fold is itself hidden by an outer fold
        bool outerFoldHidden = false;
        for (final outerFold in sortedFolds) {
          if (outerFold.key < fold.key &&
              fold.key <= outerFold.value &&
              fold.value <= outerFold.value) {
            outerFoldHidden = true;
            break;
          }
        }
        if (!outerFoldHidden) return true;
      }
    }
    return false;
  }

  int? getFoldableRegionEnd(int line, List<String> lines) {
    if (line >= lines.length) return null;

    final baseIndent = _getIndentation(lines[line]);
    if (baseIndent == -1) return null;

    int lastValidLine = line;
    bool foundContent = false;

    for (int i = line + 1; i < lines.length; i++) {
      final currentLine = lines[i].trim();
      if (currentLine.isEmpty) continue;

      final currentIndent = _getIndentation(lines[i]);
      if (currentIndent <= baseIndent) {
        return foundContent ? lastValidLine : null;
      }

      foundContent = true;
      lastValidLine = i;
    }

    return foundContent ? lastValidLine : null;
  }

  int _getIndentation(String line) {
    if (line.trim().isEmpty) return -1;
    final match = RegExp(r'[^\s]').firstMatch(line);
    return match?.start ?? -1;
  }
}
