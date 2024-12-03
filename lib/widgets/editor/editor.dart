import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/editor_core.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final EditorCore _core = EditorCore(bufferManager: BufferManager());

  KeyEventResult _handleKeyEvent(KeyEvent keyEvent) {
    if (keyEvent is! KeyDownEvent && keyEvent is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (keyEvent.character == null) return KeyEventResult.ignored;

    _core.insertChar(keyEvent.character!);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
        autofocus: true,
        onKeyEvent: (node, keyEvent) => _handleKeyEvent(keyEvent),
        child: ListenableBuilder(
            listenable: _core,
            builder: (context, child) {
              return CustomPaint(painter: EditorPainter(core: _core));
            }));
  }
}
