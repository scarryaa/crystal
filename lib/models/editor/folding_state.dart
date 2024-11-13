import 'package:flutter/material.dart';

class FoldingState extends ChangeNotifier {
  final Map<int, bool> foldedLines = {};
  final Map<int, int> foldingRanges = {};

  bool isLineHidden(int line) {
    for (final entry in foldingRanges.entries) {
      if (line > entry.key && line <= entry.value) {
        return true;
      }
    }
    return false;
  }

  bool isLineFolded(int line) => foldingRanges.containsKey(line);

  void toggleFold(int startLine, int endLine) {
    if (isLineFolded(startLine)) {
      // Unfold
      foldingRanges.remove(startLine);
    } else {
      // Fold
      // Remove any existing folds that are completely within this new fold
      foldingRanges
          .removeWhere((key, value) => key > startLine && value <= endLine);

      // Add the new fold
      foldingRanges[startLine] = endLine;
    }
    notifyListeners();
  }

  List<int> getVisibleLines(List<String> lines) {
    final visibleLines = <int>[];

    for (int i = 0; i < lines.length; i++) {
      if (!isLineHidden(i)) {
        visibleLines.add(i);
      }
    }

    return visibleLines;
  }
}
