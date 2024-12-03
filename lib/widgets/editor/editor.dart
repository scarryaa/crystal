import 'dart:math';

import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/cursor_manager.dart';
import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor_input_manager.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';

class Editor extends StatefulWidget {
  final void Function(EditorCore)? onCoreInitialized;

  const Editor({super.key, this.onCoreInitialized});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  late final EditorCore _core;
  final EditorInputManager editorInputManager = EditorInputManager();

  @override
  void initState() {
    super.initState();
    final bufferManager = BufferManager();
    _core = EditorCore(
      bufferManager: bufferManager,
      cursorManager: CursorManager(bufferManager),
      editorConfig: EditorConfig(),
    );

    _core.bufferManager.cursorManager = _core.cursorManager;
    widget.onCoreInitialized?.call(_core);
  }

  double _calculateWidgetHeight() {
    return max(MediaQuery.of(context).size.height,
        _core.lines.length * _core.config.lineHeight);
  }

  double _calculateWidgetWidth() {
    return max(MediaQuery.of(context).size.width - _core.config.minGutterWidth,
        _calculateMaxLineWidth());
  }

  double _calculateMaxLineWidth() {
    return _core.lines.fold(
        0,
        (value, element) =>
            value + element.length * _core.config.characterWidth);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: _calculateWidgetWidth(),
        height: _calculateWidgetHeight(),
        child: Focus(
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
                })));
  }
}
