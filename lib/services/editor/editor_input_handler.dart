import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorInputHandler {
  VoidCallback resetCaretBlink;
  VoidCallback requestFocus;

  EditorInputHandler({
    required this.resetCaretBlink,
    required this.requestFocus,
  });

  void handleTap(
      TapDownDetails details,
      double verticalScrollControllerOffset,
      double horizontalScrollControllerOffset,
      EditorPainter? editorPainter,
      EditorState state) {
    requestFocus();

    if (editorPainter == null) return;

    bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    final localY = details.localPosition.dy + verticalScrollControllerOffset;
    final localX = details.localPosition.dx + horizontalScrollControllerOffset;
    state.handleTap(
        localY, localX, editorPainter.measureLineWidth, isAltPressed);
    resetCaretBlink();
  }

  void handleDragStart(
      DragStartDetails details,
      double verticalScrollControllerOffset,
      double horizontalScrollControllerOffset,
      EditorPainter? editorPainter,
      EditorState state) {
    if (editorPainter == null) return;

    bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    state.handleDragStart(
        details.localPosition.dy + verticalScrollControllerOffset,
        details.localPosition.dx + horizontalScrollControllerOffset,
        editorPainter.measureLineWidth,
        isAltPressed);
  }

  void handleDragUpdate(
      DragUpdateDetails details,
      double verticalScrollControllerOffset,
      double horizontalScrollControllerOffset,
      EditorPainter? editorPainter,
      EditorState state) {
    if (editorPainter == null) return;

    state.handleDragUpdate(
        details.localPosition.dy + verticalScrollControllerOffset,
        details.localPosition.dx,
        editorPainter.measureLineWidth);
  }
}
