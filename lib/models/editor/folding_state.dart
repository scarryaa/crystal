class FoldingState {
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

  bool isLineFolded(int line) => foldedLines[line] ?? false;

  void toggleFold(int startLine, int endLine) {
    if (foldedLines[startLine] ?? false) {
      foldedLines.remove(startLine);
      foldingRanges.remove(startLine);
    } else {
      foldedLines[startLine] = true;
      foldingRanges[startLine] = endLine;
    }
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
