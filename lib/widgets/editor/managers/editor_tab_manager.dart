import 'dart:math';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:flutter/material.dart';

class EditorTabManager {
  late TabController controller;
  final List<String> tabs = [];
  final Map<String, String> fileContents = {};
  final Map<String, EditorScrollManager> scrollManagers = {};
  final TickerProvider vsync;

  EditorTabManager({required this.vsync}) {
    controller = TabController(length: 0, vsync: vsync);
  }

  void openTab(EditorScrollManager scrollManager, String path, String content) {
    if (!tabs.contains(path)) {
      tabs.add(path);
      fileContents[path] = content;
      scrollManagers[path] = scrollManager;

      final oldController = controller;
      controller = TabController(
          length: tabs.length, vsync: vsync, initialIndex: tabs.length - 1);
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
      oldController.dispose();

      tabs.removeAt(index);
      fileContents.remove(path);
      scrollManagers[path]?.dispose();
      scrollManagers.remove(path);
    }
  }

  EditorScrollManager getScrollManager(String path) {
    print(scrollManagers[path]);
    return scrollManagers[path] ?? EditorScrollManager();
  }

  String? getCurrentContent() {
    if (tabs.isEmpty) return null;
    return fileContents[tabs[controller.index]];
  }

  void dispose() {
    controller.dispose();
  }
}
