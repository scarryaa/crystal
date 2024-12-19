import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:flutter/material.dart';

class EditorContentManager extends ChangeNotifier {
  late final EditorTabController tabController;
  final Map<String, String> fileContents = {};
  final Map<String, String> originalContents = {};

  void setTabController(EditorTabController tabController) {
    this.tabController = tabController;
  }

  bool isContentDirty(String path) {
    return fileContents[path] != originalContents[path];
  }

  String? getCurrentContent() {
    if (tabController.tabs.isEmpty) return null;
    return fileContents[tabController.tabs[tabController.controller.index]];
  }

  void updateFileContent(String path, String content) {
    fileContents[path] = content;
    notifyListeners();
  }

  void updateOriginalContent(String path, String content) {
    originalContents[path] = content;
    notifyListeners();
  }
}
