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
  ) {
    double verticalOffsetTarget = core.cursorLine * core.config.lineHeight;
    double currentOffset = editorVerticalScrollController.offset;
    double bufferSpace = core.config.lineHeight * (core.config.lineBuffer + 2);

    // If cursor is below visible area (with buffer)
    if (verticalOffsetTarget + bufferSpace > screenHeight + currentOffset) {
      editorVerticalScrollController
          .jumpTo(verticalOffsetTarget - screenHeight + bufferSpace);
    }
    // If cursor is above visible area (with buffer)
    else if (verticalOffsetTarget - bufferSpace < currentOffset) {
      editorVerticalScrollController
          .jumpTo(max(0, verticalOffsetTarget - bufferSpace));
    }
  }

  void dispose() {
    editorVerticalScrollController.dispose();
    gutterVerticalScrollController.dispose();
    editorHorizontalScrollController.dispose();
  }
}
