import 'package:crystal/widgets/editor_painter.dart';
import 'package:flutter/material.dart';

class Editor extends StatefulWidget {
  const Editor({super.key});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: EditorPainter(),
    );
  }
}
