import 'dart:io';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_manager.dart';
import 'package:crystal/widgets/editor/tabs/custom_tab_bar.dart';
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
import 'package:crystal/widgets/file_explorer/viewmodel/file_explorer_view_model.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  EditorScrollManager scrollManager = EditorScrollManager();
  late final EditorTabManager tabManager;
  late final FileExplorerViewModel fileExplorerViewModel;
  final tabBarHeight = 32.0;
  final tabBarPadding = 4.0;
  double _gutterWidth = 0;

  @override
  void initState() {
    super.initState();
    fileExplorerViewModel = FileExplorerViewModel();
    tabManager = EditorTabManager(vsync: this);
  }

  void openFile(String path) {
    final file = File(path);
    file.readAsString().then((content) {
      setState(() {
        tabManager.openTab(EditorScrollManager(), path, content);
      });
    });
  }

  void _handleEditorCore(EditorCore core, String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        tabManager.registerCore(path, core);
      });
    });
  }

  @override
  void dispose() {
    scrollManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: tabManager,
        builder: (context, child) {
          final currentPath = tabManager.getCurrentPath();
          final activeCore = tabManager.getActiveCore();

          return Material(
              child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    FileExplorer(
                      width: 200,
                      viewModel: fileExplorerViewModel,
                    ),
                    Expanded(
                        child: Column(children: [
                      CustomTabBar(
                        tabBarHeight: tabBarHeight,
                        tabManager: tabManager,
                      ),
                      Expanded(
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                            if (activeCore != null && currentPath != null)
                              Gutter(
                                key: ValueKey(currentPath),
                                core: activeCore,
                                verticalScrollController: tabManager
                                    .getScrollManager(currentPath)
                                    .gutterVerticalScrollController,
                                tabBarHeight: tabBarHeight + tabBarPadding,
                                onWidthChanged: (width) {
                                  WidgetsBinding.instance.addPostFrameCallback(
                                      (_) =>
                                          setState(() => _gutterWidth = width));
                                },
                              ),
                            Expanded(
                              child: TabBarView(
                                physics: const NeverScrollableScrollPhysics(),
                                controller: tabManager.controller,
                                children: tabManager.tabs.map((path) {
                                  final scrollManager =
                                      tabManager.getScrollManager(path);
                                  return Editor(
                                    focusNode: tabManager.focusNodes[path]!,
                                    fileExplorerWidth:
                                        fileExplorerViewModel.width,
                                    gutterWidth: _gutterWidth,
                                    onCoreInitialized: (core) =>
                                        _handleEditorCore(core, path),
                                    verticalScrollController: scrollManager
                                        .editorVerticalScrollController,
                                    horizontalScrollController: scrollManager
                                        .editorHorizontalScrollController,
                                    path: path,
                                    tabBarHeight: tabBarHeight + tabBarPadding,
                                  );
                                }).toList(),
                              ),
                            ),
                          ]))
                    ])),
                  ],
                ),
              ),
            ],
          ));
        });
  }
}
