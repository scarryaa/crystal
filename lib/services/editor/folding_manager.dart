import 'package:flutter/material.dart';

class FoldingManager extends ChangeNotifier {
  final Map<int, int> _foldedRegions = {};

  bool isFolded(int line) => _foldedRegions.containsKey(line);

  void toggleFold(int startLine, int endLine) {
    if (isFolded(startLine)) {
      _foldedRegions.remove(startLine);
    } else {
      _foldedRegions[startLine] = endLine;
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

  bool isLineHidden(int line) {
    for (final entry in _foldedRegions.entries) {
      if (line > entry.key && line <= entry.value) {
        return true;
      }
    }
    return false;
  }

  int? getFoldableRegionEnd(int line, List<String> lines) {
    final baseIndent = _getIndentation(lines[line]);

    for (int i = line + 1; i < lines.length; i++) {
      final currentIndent = _getIndentation(lines[i]);
      if (currentIndent <= baseIndent && lines[i].trim().isNotEmpty) {
        return i - 1;
      }
    }

    return null;
  }

  int _getIndentation(String line) {
    return line.indexOf(RegExp(r'[^\s]'));
  }
}
