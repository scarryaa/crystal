import 'dart:io';

import 'package:crystal/widgets/editor/managers/editor_tab_manager.dart';
import 'package:crystal/widgets/editor/tabs/dirty_indicator.dart';
import 'package:flutter/material.dart';

class CustomTab extends StatefulWidget {
  final bool isDirty;
  final double tabBarHeight;
  final String path;
  final EditorTabManager tabManager;

  const CustomTab({
    super.key,
    required this.isDirty,
    required this.tabBarHeight,
    required this.path,
    required this.tabManager,
  });

  @override
  State<StatefulWidget> createState() => _CustomTabState();
}

class _CustomTabState extends State<CustomTab> {
  @override
  Widget build(BuildContext context) {
    return Tab(
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
              onPressed: () => widget.tabManager.closeTab(widget.path),
            ),
            Container(width: 8.0),
          ],
        ));
  }
}
