import 'package:crystal/core/editor/editor_core.dart';

class EditorState {
  final List<String> lines;
  final int cursorLine;
  final int cursorColumn;

  EditorState({
    required this.lines,
    required this.cursorLine,
    required this.cursorColumn,
  });

  static EditorState fromCore(EditorCore core) {
    return EditorState(
      lines: List.from(core.lines),
      cursorLine: core.cursorLine,
      cursorColumn: core.cursorPosition,
    );
  }

  void restoreToCore(EditorCore core) {
    core.lines.clear();
    core.lines.addAll(lines);

    core.moveTo(cursorLine, cursorColumn);
  }
}
