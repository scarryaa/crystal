import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';

class Gutter extends StatefulWidget {
  final EditorCore core;
  final ScrollController verticalScrollController;

  const Gutter({
    super.key,
    required this.core,
    required this.verticalScrollController,
  });

  @override
  State<StatefulWidget> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  double _calculateWidgetHeight() {
    return max(
        MediaQuery.of(context).size.height,
        (widget.core.lines.length * widget.core.config.lineHeight) +
            widget.core.config.heightPadding);
  }

  double _calculateWidgetWidth() {
    return max(
        widget.core.config.minGutterWidth,
        widget.core.lines.length.toString().length *
            widget.core.config.characterWidth);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.core,
        builder: (context, child) {
          return ScrollConfiguration(
              behavior: const ScrollBehavior().copyWith(scrollbars: false),
              child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  controller: widget.verticalScrollController,
                  child: SizedBox(
                      width: _calculateWidgetWidth(),
                      height: _calculateWidgetHeight(),
                      child: CustomPaint(
                          painter: GutterPainter(core: widget.core)))));
        });
  }
}
