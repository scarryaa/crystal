import 'package:crystal/state/editor/editor_state.dart';

class SplitView {
  final List<EditorState> editors;
  int activeEditorIndex;
  double size;

  SplitView({
    List<EditorState>? editors,
    this.activeEditorIndex = -1,
    this.size = 1.0,
  }) : editors = editors ?? [];

  EditorState? get activeEditor =>
      editors.isEmpty ? null : editors[activeEditorIndex];

  EditorState operator [](int index) => editors[index];
}
