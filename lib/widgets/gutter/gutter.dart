import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor/editor_state.dart';

class Gutter extends StatelessWidget {
  const Gutter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorState>(
      builder: (context, editorState, child) {
        final gutterWidth = math.max(
            (editorState.lines.length.toString().length * 10.0) + 20.0, 48.0);
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: MediaQuery.of(context).size.height,
            child: CustomPaint(
              painter: GutterPainter(
                lineCount: editorState.lines.length,
                cursors: editorState.cursors,
              ),
              size: Size(gutterWidth,
                  editorState.lines.length * EditorConstants.lineHeight),
            ),
          ),
        );
      },
    );
  }
}
