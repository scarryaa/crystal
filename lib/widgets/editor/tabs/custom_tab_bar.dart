import 'package:crystal/util/utils.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:crystal/widgets/editor/tabs/custom_tab.dart';
import 'package:crystal/widgets/editor/tabs/custom_tab_button.dart';
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
    return ListenableBuilder(
      listenable: widget.tabController.contentManager,
      builder: (context, child) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(color: Colors.grey, width: 0),
            ),
          ),
          height: widget.tabBarHeight,
          child: Row(
            children: [
              Expanded(
                child: TabBar(
                  splashFactory: NoSplash.splashFactory,
                  tabAlignment: TabAlignment.start,
                  controller: widget.tabController.controller,
                  isScrollable: true,
                  labelPadding: EdgeInsets.zero,
                  indicatorPadding: EdgeInsets.zero,
                  padding: EdgeInsets.zero,
                  indicator: const BoxDecoration(
                    color: Colors.transparent,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey,
                        width: 1,
                      ),
                    ),
                  ),
                  tabs: widget.tabController.tabs.map((path) {
                    return CustomTab(
                      isDirty: widget.tabController.contentManager
                          .isContentDirty(path),
                      tabController: widget.tabController,
                      path: path,
                      tabBarHeight: widget.tabBarHeight,
                    );
                  }).toList(),
                ),
              ),
              CustomTabButton(
                tabController: widget.tabController,
                icon: Icons.add,
                iconSize: 16,
                onPressed: () async {
                  final tempPath = await Utils.getTempPath();
                  widget.tabController.openTab(
                    EditorScrollManager(),
                    tempPath,
                    '',
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
