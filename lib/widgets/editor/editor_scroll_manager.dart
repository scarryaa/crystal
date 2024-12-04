import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:flutter/material.dart';

class EditorScrollManager {
  final ScrollController editorVerticalScrollController = ScrollController();
  final ScrollController editorHorizontalScrollController = ScrollController();
  final ScrollController gutterVerticalScrollController = ScrollController();

  EditorScrollManager() {
    _initializeScrollSync();
  }

  void _initializeScrollSync() {
    editorVerticalScrollController.addListener(() {
      if (gutterVerticalScrollController.offset !=
          editorVerticalScrollController.offset) {
        gutterVerticalScrollController
            .jumpTo(editorVerticalScrollController.offset);
      }
    });

    gutterVerticalScrollController.addListener(() {
      if (gutterVerticalScrollController.offset !=
          editorVerticalScrollController.offset) {
        editorVerticalScrollController
            .jumpTo(gutterVerticalScrollController.offset);
      }
    });
  }

  void jumpToCursor(
    EditorCore core,
    double screenHeight,
    double screenWidth,
  ) {
    double verticalOffsetTarget = core.cursorLine * core.config.lineHeight;
    double currentOffset = editorVerticalScrollController.offset;
    double bufferSpace = core.config.lineHeight * (core.config.lineBuffer + 2);

    // If cursor is below visible area
    if (verticalOffsetTarget + bufferSpace > screenHeight + currentOffset) {
      editorVerticalScrollController
          .jumpTo(verticalOffsetTarget - screenHeight + bufferSpace);
    }
    // If cursor is above visible area
    else if (verticalOffsetTarget - bufferSpace < currentOffset) {
      editorVerticalScrollController
          .jumpTo(max(0, verticalOffsetTarget - bufferSpace));
    }

    // Horizontal scrolling
    double horizontalOffsetTarget =
        core.cursorPosition * core.config.characterWidth;
    double currentHorizontalOffset = editorHorizontalScrollController.offset;
    double horizontalBufferSpace = core.config.widthPadding;

    // If cursor is to the right of visible area
    if (horizontalOffsetTarget + horizontalBufferSpace >
        screenWidth + currentHorizontalOffset) {
      editorHorizontalScrollController
          .jumpTo(horizontalOffsetTarget - screenWidth + horizontalBufferSpace);
    }
    // If cursor is to the left of visible area
    else if (horizontalOffsetTarget - horizontalBufferSpace <
        currentHorizontalOffset) {
      editorHorizontalScrollController
          .jumpTo(max(0, horizontalOffsetTarget - horizontalBufferSpace));
    }
  }

  void dispose() {
    editorVerticalScrollController.dispose();
    gutterVerticalScrollController.dispose();
    editorHorizontalScrollController.dispose();
  }
}
