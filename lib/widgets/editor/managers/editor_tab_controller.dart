import 'dart:math';

import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/widgets/editor/managers/editor_content_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_state_manager.dart';
import 'package:flutter/material.dart';

class EditorTabController extends ChangeNotifier {
  final EditorStateManager stateManager;
  final EditorContentManager contentManager;
  final TickerProvider vsync;
  final List<String> tabs = [];
  late TabController controller;

  EditorTabController({
    required this.stateManager,
    required this.contentManager,
    required this.vsync,
  }) {
    controller = TabController(
        length: 0, vsync: vsync, animationDuration: Duration.zero);
    controller.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!controller.indexIsChanging) {
      // Save cursor state of previous tab
      final previousPath = tabs[controller.previousIndex];
      final previousCore = stateManager.cores[previousPath];
      if (previousCore != null) {
        stateManager.updateCursorPosition(previousPath,
            previousCore.cursorLine ?? 0, previousCore.cursorPosition ?? 0);
      }

      // Restore state of new tab
      final currentPath = getCurrentPath();
      if (currentPath == null) return;

      final core = stateManager.cores[currentPath];
      final cursorPositions = stateManager.cursorPositions[currentPath];
      if (core != null &&
          cursorPositions != null &&
          cursorPositions.isNotEmpty) {
        core.cursorManager.clearCursors(keepAnchor: false);
        for (var pos in cursorPositions) {
          if (pos.$1 >= 0 && pos.$2 >= 0) {
            core.cursorManager.addCursor(Cursor(line: pos.$1, index: pos.$2));
          }
        }
      }

      stateManager.focusNodes[currentPath]?.requestFocus();

      notifyListeners();
    }
  }

  void openTab(EditorScrollManager scrollManager, String path, String content) {
    if (!tabs.contains(path)) {
      tabs.add(path);
      contentManager.fileContents[path] = content;
      contentManager.originalContents[path] = content;
      stateManager.scrollManagers[path] = scrollManager;
      stateManager.focusNodes[path] = FocusNode();

      final oldController = controller;
      oldController.removeListener(_handleTabChange);
      initController();
      oldController.dispose();
    } else {
      controller.animateTo(tabs.indexOf(path));
    }

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => stateManager.focusNodes[path]?.requestFocus());
  }

  void closeTab(EditorScrollManager scrollManager, String path) {
    final index = tabs.indexOf(path);
    if (index != -1) {
      final oldController = controller;
      controller = TabController(
          length: max(0, tabs.length - 1),
          vsync: vsync,
          initialIndex: max(0, index - 1),
          animationDuration: Duration.zero);

      tabs.removeAt(index);
      contentManager.fileContents.remove(path);
      stateManager.scrollManagers[path]?.dispose();
      stateManager.scrollManagers.remove(path);
      oldController.dispose();
      notifyListeners();

      WidgetsBinding.instance.addPostFrameCallback((_) => _handleTabChange());
    }
  }

  void initController() {
    controller = TabController(
        length: tabs.length,
        vsync: vsync,
        animationDuration: Duration.zero,
        initialIndex: tabs.length - 1);

    controller.addListener(_handleTabChange);
    notifyListeners();
  }

  String? getCurrentPath() {
    if (tabs.isEmpty) return null;
    if (controller.index < 0 || controller.index >= tabs.length) return null;
    if (controller.indexIsChanging) return null;

    return tabs[controller.index];
  }

  @override
  void dispose() {
    controller.removeListener(_handleTabChange);
    controller.dispose();
    super.dispose();
  }
}
