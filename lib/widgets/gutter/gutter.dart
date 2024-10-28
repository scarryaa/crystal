import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor/editor_state.dart';

class Gutter extends StatefulWidget {
  final ScrollController verticalScrollController;
  final EditorState editorState;

  const Gutter(
      {super.key,
      required this.verticalScrollController,
      required this.editorState});

  @override
  State<Gutter> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  EditorState get editorState => widget.editorState;
  double get gutterWidth => editorState.getGutterWidth();

  @override
  Widget build(BuildContext context) {
    double height = max(
        MediaQuery.of(context).size.height,
        (editorState.lines.length * EditorConstants.lineHeight) +
            EditorConstants.verticalPadding);

    return Consumer<EditorState>(
      builder: (context, editorState, child) {
        return ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: SingleChildScrollView(
              controller: widget.verticalScrollController,
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  child: CustomPaint(
                      painter: GutterPainter(
                        lineCount: editorState.lines.length,
                        cursor: editorState.cursor,
                        verticalOffset:
                            widget.verticalScrollController.hasClients
                                ? widget.verticalScrollController.offset
                                : 0,
                        viewportHeight: MediaQuery.of(context).size.height,
                      ),
                      size: Size(gutterWidth, height)),
                ),
              ),
            ));
      },
    );
  }
}
