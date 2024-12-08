import 'dart:io';
import 'dart:math';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/managers/editor_mouse_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
  final Map<String, (int, int, int, int, int)> selections = {};
  final Map<String, (int, int)> cursorPositions = {};
  final Map<String, EditorCore> cores = {};
  late TabController controller;
  final List<String> tabs = [];
  final Map<String, String> fileContents = {};
  final Map<String, EditorScrollManager> scrollManagers = {};
  final TickerProvider vsync;

  EditorTabManager({required this.vsync}) {
    controller = TabController(
        length: 0, vsync: vsync, animationDuration: Duration.zero);
  }

  void initController() {
    controller = TabController(
        length: tabs.length,
        vsync: vsync,
        animationDuration: Duration.zero,
        initialIndex: tabs.length - 1);

    controller.addListener(_handleTabChange);
  }

  void _handleTabChange() {
    if (!controller.indexIsChanging) {
      final currentPath = getCurrentPath();
      if (currentPath == null) return;

      final scrollManager = scrollManagers[currentPath];
      if (scrollManager == null) return;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (scrollManager.gutterVerticalScrollController.hasClients &&
            scrollManager.editorVerticalScrollController.hasClients) {
          scrollManager.gutterVerticalScrollController
              .jumpTo(scrollManager.editorVerticalScrollController.offset);
        }
      });
      notifyListeners();
    }
  }

  void _handleCursorMove(String path, int line, int column) {
    final scrollManager = getScrollManager(path);
    final core = cores[path];
    if (core == null) return;

    cursorPositions[path] =
        (core.cursorManager.cursorLine, core.cursorManager.cursorIndex);
    scrollManager.jumpToCursor(
      core,
      scrollManager.editorVerticalScrollController.position.viewportDimension,
      scrollManager.editorHorizontalScrollController.position.viewportDimension,
    );
  }

  void registerCore(String path, EditorCore core) {
    cores[path] = core;
    core.onCursorMove = (line, column) => _handleCursorMove(path, line, column);
    core.forceRefresh = () => _forceRefresh(path);
    core.onEdit = (content) => fileContents[path] = content;
    core.onSelectionChange =
        (anchor, startIndex, endIndex, startLine, endLine) {
      selections[path] = (anchor, startIndex, endIndex, startLine, endLine);
    };

    final content = fileContents[path] ?? File(path).readAsStringSync();
    fileContents[path] = content;
    core.setBuffer(content);

    if (selections[path] != null) {
      final selection = selections[path]!;
      core.selectRange(selection.$4, selection.$2, selection.$5, selection.$3);
    }

    if (cursorPositions[path] != null) {
      core.moveCursorTo(cursorPositions[path]!.$1, cursorPositions[path]!.$2);
    }
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
    if (tabs.isEmpty) return null;
    return cores[tabs[controller.index]];
  }

  void openTab(EditorScrollManager scrollManager, String path, String content) {
    if (!tabs.contains(path)) {
      tabs.add(path);
      fileContents[path] = content;
      scrollManagers[path] = scrollManager;

      final oldController = controller;
      oldController.removeListener(_handleTabChange);
      initController();
      oldController.dispose();
    } else {
      controller.animateTo(tabs.indexOf(path));
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleTabChange);
    controller.dispose();
    super.dispose();
  }

  void closeTab(String path) {
    final index = tabs.indexOf(path);
    if (index != -1) {
      final oldController = controller;
      controller = TabController(
          length: max(0, tabs.length - 1),
          vsync: vsync,
          initialIndex: max(0, index - 1),
          animationDuration: Duration.zero);

      tabs.removeAt(index);
      fileContents.remove(path);
      scrollManagers[path]?.dispose();
      scrollManagers.remove(path);
      oldController.dispose();
      notifyListeners();
    }
  }

  EditorScrollManager getScrollManager(String path) {
    return scrollManagers[path] ?? EditorScrollManager();
  }

  String? getCurrentContent() {
    if (tabs.isEmpty) return null;
    return fileContents[tabs[controller.index]];
  }

  String? getCurrentPath() {
    if (tabs.isEmpty) return null;
    if (controller.index < 0 || controller.index >= tabs.length) return null;

    return tabs[controller.index];
  }
}
