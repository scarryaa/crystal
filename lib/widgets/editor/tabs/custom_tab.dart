import 'dart:io';

import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:crystal/widgets/editor/tabs/dirty_indicator.dart';
import 'package:flutter/material.dart';

class CustomTab extends StatefulWidget {
  final bool isDirty;
  final double tabBarHeight;
  final String path;
  final EditorTabController tabController;

  const CustomTab({
    super.key,
    required this.isDirty,
    required this.tabBarHeight,
    required this.path,
    required this.tabController,
  });

  @override
  State<StatefulWidget> createState() => _CustomTabState();
}

class _CustomTabState extends State<CustomTab> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTertiaryTapDown: (_) => widget.tabController.closeTab(widget.path),
        child: Container(
            padding: const EdgeInsets.only(left: 12.0, top: 2.0),
            decoration: BoxDecoration(
                color: widget.tabController.controller.index ==
                        widget.tabController.tabs.indexOf(widget.path)
                    ? Theme.of(context).primaryColor.withOpacity(0.2)
                    : Colors.transparent,
                border: const Border(
                    right: BorderSide(color: Colors.grey, width: 1))),
            child: Tab(
                height: widget.tabBarHeight,
                child: Row(
                  children: [
                    DirtyIndicator(isDirty: widget.isDirty),
                    Container(width: 8.0),
                    Text(widget.path.split(Platform.pathSeparator).last),
                    Container(width: 8.0),
                    IconButton(
                      hoverColor: Colors.grey.withOpacity(0.5),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      style: IconButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () =>
                          widget.tabController.closeTab(widget.path),
                    ),
                    Container(width: 8.0),
                  ],
                ))));
  }
}
