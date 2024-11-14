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
        localY, // Pass actual Y coordinate
        localX,
        editorPainter.measureLineWidth,
        isAltPressed);
    resetCaretBlink();
  }

  void handleDragStart(
      DragStartDetails details,
      double verticalScrollControllerOffset,
      double horizontalScrollControllerOffset,
      EditorPainter? editorPainter,
      EditorState state) {
    requestFocus();
    if (editorPainter == null) return;

    final localY = details.localPosition.dy + verticalScrollControllerOffset;
    final localX = details.localPosition.dx + horizontalScrollControllerOffset;

    bool isAltPressed = HardwareKeyboard.instance.isAltPressed;

    state.handleDragStart(
        localY, // Pass actual Y coordinate
        localX,
        editorPainter.measureLineWidth,
        isAltPressed);
  }

  void handleDragUpdate(
      DragUpdateDetails details,
      double verticalScrollControllerOffset,
      double horizontalScrollControllerOffset,
      EditorPainter? editorPainter,
      EditorState state) {
    requestFocus();
    if (editorPainter == null) return;

    final localY = details.localPosition.dy + verticalScrollControllerOffset;
    final localX = details.localPosition.dx + horizontalScrollControllerOffset;

    state.handleDragUpdate(
        localY, // Pass actual Y coordinate
        localX,
        editorPainter.measureLineWidth);
  }

  int _getBufferLineFromY(double y, EditorState state) {
    int visualLine = y ~/ state.editorLayoutService.config.lineHeight;

    // Count visible lines up to the target visual line
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (
        currentVisualLine < visualLine && bufferLine < state.buffer.lineCount) {
      //TODO refactor to not expose state.foldingManager?
      if (!state.foldingManager.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    // Skip any hidden lines
    while (bufferLine < state.buffer.lineCount &&
        // TODO refactor?
        state.foldingManager.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return bufferLine.clamp(0, state.buffer.lineCount - 1);
  }
}
