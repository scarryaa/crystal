import 'package:crystal/state/editor/editor_state.dart';

class SplitView {
  final List<EditorState> editors;
  int activeEditorIndex;

  SplitView({
    List<EditorState>? editors,
    this.activeEditorIndex = -1,
  }) : editors = editors ?? [];

  EditorState? get activeEditor =>
      editors.isEmpty ? null : editors[activeEditorIndex];
}
