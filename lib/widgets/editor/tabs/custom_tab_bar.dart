import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:crystal/widgets/editor/tabs/custom_tab.dart';
import 'package:flutter/material.dart';

class CustomTabBar extends StatefulWidget {
  final EditorTabController tabController;
  final double tabBarHeight;

  const CustomTabBar({
    super.key,
    required this.tabController,
    required this.tabBarHeight,
  });

  @override
  State<StatefulWidget> createState() => _CustomTabBarState();
}

class _CustomTabBarState extends State<CustomTabBar> {
  @override
  Widget build(BuildContext context) {
    return TabBar(
      splashFactory: NoSplash.splashFactory,
      tabAlignment: TabAlignment.start,
      controller: widget.tabController.controller,
      isScrollable: true,
      labelPadding: EdgeInsets.zero,
      indicatorPadding: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      indicator: const BoxDecoration(border: Border(bottom: BorderSide.none)),
      tabs: widget.tabController.tabs.map((path) {
        return CustomTab(
            isDirty: widget.tabController.contentManager.isContentDirty(path),
            tabController: widget.tabController,
            path: path,
            tabBarHeight: widget.tabBarHeight);
      }).toList(),
    );
  }
}
