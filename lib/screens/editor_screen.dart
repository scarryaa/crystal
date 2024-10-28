import 'package:crystal/state/editor_state.dart';
import 'package:crystal/widgets/editor.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final EditorState _editorState = EditorState();

  @override
  Widget build(BuildContext context) {
    return Editor(state: _editorState);
  }
}
