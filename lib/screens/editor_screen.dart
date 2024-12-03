import 'package:crystal/core/buffer_manager.dart';
import 'package:crystal/core/editor_core.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatelessWidget {
  final EditorCore core = EditorCore(bufferManager: BufferManager());

  EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: EditorPainter(core: core));
  }
}
