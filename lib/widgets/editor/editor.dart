import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor_input_manager.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final EditorCore _core = EditorCore(
    bufferManager: BufferManager(),
    editorConfig: EditorConfig(),
  );

  final EditorInputManager editorInputManager = EditorInputManager();

  @override
  Widget build(BuildContext context) {
    return Focus(
        autofocus: true,
        onKeyEvent: (node, keyEvent) =>
            editorInputManager.handleKeyEvent(_core, keyEvent),
        child: ListenableBuilder(
            listenable: _core,
            builder: (context, child) {
              return CustomPaint(
                  painter: EditorPainter(
                core: _core,
              ));
            }));
  }
}
