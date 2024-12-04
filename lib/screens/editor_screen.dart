import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorCore? core;
  EditorScrollManager scrollManager = EditorScrollManager();

  @override
  void dispose() {
    scrollManager.dispose();
    super.dispose();
  }

  void _handleEditorCore(EditorCore core) {
    // Needed to prevent setState during build error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        this.core = core;
        core.onCursorMove = _handleCursorMove;
        core.forceRefresh = _forceRefresh;
      });
    });
  }

  void _handleCursorMove(int line, int column) {
    scrollManager.jumpToCursor(
      core!,
      scrollManager.editorVerticalScrollController.position.viewportDimension,
      scrollManager.editorHorizontalScrollController.position.viewportDimension,
    );
  }

  void _forceRefresh() {
    setState(() {
      // Recalculate scroll positions
      scrollManager.recalculateScrollPosition(
        core!,
        scrollManager.editorVerticalScrollController.position.viewportDimension,
        scrollManager
            .editorHorizontalScrollController.position.viewportDimension,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (core != null)
          Gutter(
            core: core!,
            verticalScrollController:
                scrollManager.gutterVerticalScrollController,
          ),
        Expanded(
          child: Editor(
            onCoreInitialized: _handleEditorCore,
            verticalScrollController:
                scrollManager.editorVerticalScrollController,
            horizontalScrollController:
                scrollManager.editorHorizontalScrollController,
          ),
        ),
      ],
    );
  }
}
