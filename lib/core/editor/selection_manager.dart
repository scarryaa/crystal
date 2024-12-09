import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';

class SelectionManager {
  Selection selection = Selection();

  int get startLine => selection.startLine;
  int get endLine => selection.endLine;
  int get startIndex => selection.startIndex;
  int get endIndex => selection.endIndex;
  int get anchor => selection.anchor;

  void startSelection(int line, int index) {
    selection.start(line, index);
  }

  void selectAll(BufferManager bufferManager) {
    if (bufferManager.lines.isEmpty) {
      selection.start(0, 0);
      return;
    }
    selection.startLine = 0;
    selection.startIndex = 0;
    selection.anchor = 0;
    selection.endLine = bufferManager.lines.length - 1;
    selection.endIndex = bufferManager.lines[selection.endLine].length;
  }

  String getSelectedText(BufferManager bufferManager) {
    return selection.getSelectedText(bufferManager);
  }

  void deleteSelection(BufferManager bufferManager, int cursorIndex) {
    selection.deleteSelection(bufferManager, cursorIndex);
  }

  bool hasSelection() {
    return selection.hasSelection();
  }

  void updateSelection(BufferManager bufferManager,
      SelectionDirection direction, int currentIndex, int targetIndex) {
    selection.updateSelection(
        bufferManager, direction, currentIndex, targetIndex);
  }

  int selectWord(BufferManager bufferManager, int cursorLine, int cursorIndex) {
    return selection.selectWord(
      bufferManager,
      cursorLine,
      cursorIndex,
    );
  }

  void selectLine(BufferManager bufferManager, int cursorLine) {
    selection.selectLine(bufferManager, cursorLine);
  }

  void selectRange(BufferManager bufferManager, int startLine, int startIndex,
      int endLine, int endIndex) {
    selection.selectRange(
        bufferManager, startLine, startIndex, endLine, endIndex);
  }
}
