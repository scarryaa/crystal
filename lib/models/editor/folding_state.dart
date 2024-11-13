import 'package:flutter/material.dart';

class FoldingState extends ChangeNotifier {
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

  void fold(int startLine, int endLine) {
    foldingRanges[startLine] = endLine;
    notifyListeners();
  }

  void unfold(int startLine) {
    foldingRanges.remove(startLine);
    notifyListeners();
  }

  void toggleFold(int startLine, int endLine, {Map<int, int>? nestedFolds}) {
    if (isLineFolded(startLine)) {
      unfold(startLine);
      if (nestedFolds != null) {
        foldingRanges.addAll(nestedFolds);
      }
    } else {
      fold(startLine, endLine);
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
