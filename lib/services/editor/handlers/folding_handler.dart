import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/folding_manager.dart';

class FoldingHandler {
  Buffer buffer;
  FoldingManager foldingManager;
  Function() notifyListeners;

  FoldingHandler({
    required this.buffer,
    required this.foldingManager,
    required this.notifyListeners,
  });

  bool isLineHidden(int line) {
    return foldingManager.isLineHidden(line);
  }

  bool isLineFolded(int line) {
    return foldingManager.isLineFolded(line);
  }

  void toggleFold(int startLine, int endLine, {Map<int, int>? nestedFolds}) {
    // Check if the region is currently folded
    bool isFolded = buffer.foldedRanges.containsKey(startLine);

    if (isFolded) {
      // Unfold the region
      buffer.unfoldLines(startLine);
    } else {
      // Fold the region
      buffer.foldLines(startLine, endLine);
    }

    foldingManager.toggleFold(startLine, endLine);
    notifyListeners();
  }

  bool isFoldable(int line) {
    if (line >= buffer.lines.length) return false;

    final currentLine = buffer.lines[line].trim();
    if (currentLine.isEmpty) return false;

    // Check if line ends with block starter
    if (!currentLine.endsWith('{') &&
        !currentLine.endsWith('(') &&
        !currentLine.endsWith('[')) {
      return false;
    }

    final currentIndent = _getIndentation(buffer.lines[line]);

    // Look ahead for valid folding range
    int nextLine = line + 1;
    bool hasContent = false;

    while (nextLine < buffer.lines.length) {
      final nextLineText = buffer.lines[nextLine];
      if (nextLineText.trim().isEmpty) {
        nextLine++;
        continue;
      }

      final nextIndent = _getIndentation(nextLineText);
      if (nextIndent <= currentIndent) {
        return hasContent;
      }
      hasContent = true;
      nextLine++;
    }

    return false;
  }

  int _getIndentation(String line) {
    final match = RegExp(r'[^\s]').firstMatch(line);
    return match?.start ?? -1;
  }
}
