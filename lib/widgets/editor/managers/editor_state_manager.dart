import 'dart:io';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/widgets/editor/managers/editor_content_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_mouse_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:flutter/material.dart';

class EditorStateManager extends ChangeNotifier {
  final EditorContentManager contentManager;
  late final EditorTabController tabController;

  final Map<String, EditorCore> cores = {};
  final Map<String, (int, int)> cursorPositions = {};
  final Map<String, Selection> selections = {};
  final Map<String, FocusNode> focusNodes = {};
  final Map<String, EditorScrollManager> scrollManagers = {};
  final Map<String, Offset> scrollPositions = {};

  EditorStateManager({
    required this.contentManager,
  });

  void setTabController(EditorTabController tabController) {
    this.tabController = tabController;
  }

  void updateCursorPosition(String path, int line, int column) {
    final core = cores[path];
    if (core == null) return;

    // TODO
    //cursorPositions[path] =
    //(core.cursorManager.cursorLine, core.cursorManager.cursorIndex);
    core.cursorManager.targetCursorIndex = column;
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

  void registerCore(String path, EditorCore core) {
    cores[path] = core;
    core.onCursorMove =
        (line, column) => updateCursorPosition(path, line, column);
    core.forceRefresh = () => _forceRefresh(path);
    core.onEdit = (content) => contentManager.updateFileContent(path, content);
    core.onSelectionChange =
        (anchor, startIndex, endIndex, startLine, endLine) {
      selections[path] = Selection(
          anchor: anchor,
          startIndex: startIndex,
          endIndex: endIndex,
          startLine: startLine,
          endLine: endLine);
    };

    final content =
        contentManager.fileContents[path] ?? File(path).readAsStringSync();
    contentManager.updateFileContent(path, content);
    core.setBuffer(content);

    // Prevents the first line from being highlighted on tab switch when the selection is out of bounds
    if (selections[path] != null && selections[path]!.hasSelection()) {
      final selection = selections[path]!;
      core.selectRange(selection.startLine, selection.startIndex,
          selection.endLine, selection.endIndex);
    }

    if (cursorPositions[path] != null) {
      core.moveCursorTo(
          0, cursorPositions[path]!.$1, cursorPositions[path]!.$2);
    }
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
