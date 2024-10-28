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
            child: GestureDetector(
                onTapDown: _handleGutterTap,
                onPanStart: _handleGutterDragStart,
                onPanUpdate: _handleGutterDrag,
                child: SingleChildScrollView(
                  controller: widget.verticalScrollController,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      child: CustomPaint(
                          painter: GutterPainter(
                            editorState: editorState,
                            verticalOffset:
                                widget.verticalScrollController.hasClients
                                    ? widget.verticalScrollController.offset
                                    : 0,
                            viewportHeight: MediaQuery.of(context).size.height,
                          ),
                          size: Size(gutterWidth, height)),
                    ),
                  ),
                )));
      },
    );
  }

  void _handleGutterTap(TapDownDetails details) {
    _handleGutterSelection(details.localPosition.dy, false);
  }

  void _handleGutterDragStart(DragStartDetails details) {
    _handleGutterSelection(details.localPosition.dy, false);
  }

  void _handleGutterSelection(double localY, bool isMultiSelect) {
    double adjustedY = localY + editorState.scrollState.verticalOffset;
    int targetLine = adjustedY ~/ EditorConstants.lineHeight;

    // If out of range, select the last line
    if (targetLine > editorState.lines.length) {
      editorState.selectLine(isMultiSelect, editorState.lines.length - 1);
    } else {
      editorState.selectLine(isMultiSelect, targetLine);
    }
  }

  void _handleGutterDrag(DragUpdateDetails details) {
    // Select multiple lines
    double adjustedY =
        details.localPosition.dy + editorState.scrollState.verticalOffset;
    editorState.selectLine(true, adjustedY ~/ EditorConstants.lineHeight);
  }
}
