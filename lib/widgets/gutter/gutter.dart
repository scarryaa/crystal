import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';

class Gutter extends StatefulWidget {
  final EditorCore core;

  const Gutter({super.key, required this.core});

  @override
  State<StatefulWidget> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  double _calculateWidgetHeight() {
    return max(MediaQuery.of(context).size.height,
        widget.core.lines.length * widget.core.config.lineHeight);
  }

  double _calculateWidgetWidth() {
    return max(widget.core.config.minGutterWidth,
        widget.core.lines.length * widget.core.config.characterWidth);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
        width: _calculateWidgetWidth(),
        height: _calculateWidgetHeight(),
        child: CustomPaint(painter: GutterPainter(core: widget.core)));
  }
}
