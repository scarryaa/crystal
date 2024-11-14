import 'dart:math';

import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorScrollManager {
  final ScrollController gutterScrollController = ScrollController();
  final ScrollController editorVerticalScrollController = ScrollController();
  final ScrollController editorHorizontalScrollController = ScrollController();

  void initListeners({
    required Function() onEditorScroll,
    required Function() onGutterScroll,
  }) {
    editorVerticalScrollController.addListener(onEditorScroll);
    editorHorizontalScrollController.addListener(onEditorScroll);
    gutterScrollController.addListener(onGutterScroll);
  }

  void removeListeners({
    required Function() onEditorScroll,
    required Function() onGutterScroll,
  }) {
    editorVerticalScrollController.removeListener(onEditorScroll);
    editorHorizontalScrollController.removeListener(onEditorScroll);
    gutterScrollController.removeListener(onGutterScroll);
  }

  void dispose() {
    gutterScrollController.dispose();
    editorVerticalScrollController.dispose();
    editorHorizontalScrollController.dispose();
  }

  void scrollToCursor({
    required EditorState? activeEditor,
    required EditorLayoutService layoutService,
  }) {
    if (activeEditor == null) return;

    final cursor = activeEditor.editorCursorManager.cursors.last;
    final cursorBufferLine = cursor.line;
    final lineHeight = layoutService.config.lineHeight;
    final viewportHeight =
        editorVerticalScrollController.position.viewportDimension;
    final currentOffset = editorVerticalScrollController.offset;
    final verticalPadding = layoutService.config.verticalPadding;

    // Calculate visual line by counting only visible lines
    int visualLine = 0;
    for (int i = 0; i < cursorBufferLine; i++) {
      if (!activeEditor.foldingManager.isLineHidden(i)) {
        visualLine++;
      }
    }

    // Vertical scrolling using visual line position
    final cursorY = visualLine * lineHeight;
    if (cursorY < currentOffset + verticalPadding) {
      editorVerticalScrollController.jumpTo(max(0, cursorY - verticalPadding));
    } else if (cursorY + lineHeight >
        currentOffset + viewportHeight - verticalPadding) {
      editorVerticalScrollController
          .jumpTo(cursorY + lineHeight - viewportHeight + verticalPadding);
    }

    // Horizontal scrolling
    final cursorColumn = cursor.column;
    final currentLine = activeEditor.buffer.getLine(cursorBufferLine);
    final safeColumn = min(cursorColumn, currentLine.length);
    final textBeforeCursor = currentLine.substring(0, safeColumn);
    final cursorX = textBeforeCursor.length * layoutService.config.charWidth;
    final viewportWidth =
        editorHorizontalScrollController.position.viewportDimension;
    final currentHorizontalOffset = editorHorizontalScrollController.offset;
    final horizontalPadding = layoutService.config.horizontalPadding;

    if (cursorX < currentHorizontalOffset + horizontalPadding) {
      editorHorizontalScrollController
          .jumpTo(max(0, cursorX - horizontalPadding));
    } else if (cursorX + layoutService.config.charWidth >
        currentHorizontalOffset + viewportWidth - horizontalPadding) {
      editorHorizontalScrollController.jumpTo(cursorX +
          layoutService.config.charWidth -
          viewportWidth +
          horizontalPadding);
    }

    // Update editor offsets
    activeEditor
        .updateVerticalScrollOffset(editorVerticalScrollController.offset);
    activeEditor
        .updateHorizontalScrollOffset(editorHorizontalScrollController.offset);
  }

  void resetGutterScroll() {
    if (gutterScrollController.hasClients) {
      gutterScrollController.jumpTo(0);
    }
  }
}
