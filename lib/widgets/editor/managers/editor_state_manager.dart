import 'dart:io';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/widgets/editor/managers/editor_content_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:flutter/material.dart';

class EditorStateManager extends ChangeNotifier {
  final EditorContentManager contentManager;
  late final EditorTabController tabController;

  final Map<String, EditorCore> cores = {};
  final Map<String, List<(int, int)>> cursorPositions = {};
  final Map<String, List<Selection>> selections = {};
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, EditorScrollManager> scrollManagers = {};
  final Map<String, Offset> scrollPositions = {};

  EditorStateManager({
    required this.contentManager,
  });

  void setTabController(EditorTabController tabController) {
    this.tabController = tabController;
  }

  void updateCursorPosition(String path, int line, int column,
      {bool jumpToCursor = true}) {
    final core = cores[path];
    if (core == null) return;

    final layerLength = core.cursorManager.layers[0].length;

    if (layerLength > 0) {
      cursorPositions[path] = List<(int, int)>.filled(layerLength, (0, 0));

      for (int i = 0; i < layerLength; i++) {
        cursorPositions[path]?[i] = (
          core.cursorManager.layers[0][i].line,
          core.cursorManager.layers[0][i].index
        );
      }
    }

    if (jumpToCursor) {
      scrollManagers[path]?.jumpToCursor(
        core,
        scrollManagers[path]!
            .editorVerticalScrollController
            .position
            .viewportDimension,
        scrollManagers[path]!
            .editorHorizontalScrollController
            .position
            .viewportDimension,
      );
    }
  }

  void registerCore(String path, EditorCore core) {
    cores[path] = core;

    if (cursorPositions[path] != null) {
      core.cursorManager.clearCursors(keepAnchor: false);
      for (var position in cursorPositions[path]!) {
        if (position.$1 >= 0 && position.$2 >= 0) {
          core.cursorManager
              .addCursor(Cursor(line: position.$1, index: position.$2));
        }
      }
    }

    if (selections[path] != null) {
      core.selectionManager.clearSelections(0);
      for (var selection in selections[path]!) {
        core.selectionManager.addSelection(selection, layer: 0);
      }
    }

    core.onCursorMove = (line, column) {
      if (line == null || column == null) return;
      updateCursorPosition(path, line, column);
    };
    core.forceRefresh = () => _forceRefresh(path);
    core.onEdit = (content) => contentManager.updateFileContent(path, content);

    final content =
        contentManager.fileContents[path] ?? File(path).readAsStringSync();
    contentManager.updateFileContent(path, content);
    core.setBuffer(content);
  }

  EditorScrollManager getScrollManager(String path) {
    return scrollManagers[path] ?? EditorScrollManager();
  }

  void _forceRefresh(String path) {
    final scrollManager = getScrollManager(path);
    final core = cores[path];
    if (core == null) return;

    scrollManager.recalculateScrollPosition(
      core,
      scrollManager.editorVerticalScrollController.position.viewportDimension,
      scrollManager.editorHorizontalScrollController.position.viewportDimension,
    );
  }

  EditorCore? getActiveCore() {
    if (tabController.tabs.isEmpty) return null;
    return cores[tabController.tabs[tabController.controller.index]];
  }
}
