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

  void dispose() {
    editorVerticalScrollController.dispose();
    gutterVerticalScrollController.dispose();
    editorHorizontalScrollController.dispose();
  }
}
