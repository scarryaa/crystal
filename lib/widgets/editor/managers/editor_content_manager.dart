import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';

class EditorContentManager {
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
}
