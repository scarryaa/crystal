import 'dart:io';
import 'dart:math';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
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

  void _handleCursorMove(String path, int line, int column) {
    final scrollManager = getScrollManager(path);
    final core = cores[path];
    if (core == null) return;

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

    final content = fileContents[path] ?? File(path).readAsStringSync();
    fileContents[path] = content;
    core.setBuffer(content);
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
      controller = TabController(
          length: tabs.length,
          vsync: vsync,
          initialIndex: tabs.length - 1,
          animationDuration: Duration.zero);

      oldController.dispose();
    } else {
      controller.animateTo(tabs.indexOf(path));
    }
  }

  void closeTab(String path) {
    final index = tabs.indexOf(path);
    if (index != -1) {
      final oldController = controller;
      controller = TabController(
          length: max(0, tabs.length - 1),
          vsync: vsync,
          initialIndex: max(0, index - 1));

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

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
