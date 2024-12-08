import 'dart:io';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_manager.dart';
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
  EditorCore? core;
  EditorScrollManager scrollManager = EditorScrollManager();
  late final EditorTabManager tabManager;
  late final FileExplorerViewModel fileExplorerViewModel;
  final tabBarHeight = 48.0;

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
        if (core != null) {
          core!.bufferManager.setText(content);
        }
      });
    });
  }

  @override
  void dispose() {
    scrollManager.dispose();
    super.dispose();
  }

  void _handleEditorCore(EditorCore core) {
    // Needed to prevent setState during build error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        this.core = core;
        core.onCursorMove = _handleCursorMove;
        core.forceRefresh = _forceRefresh;
      });
    });
  }

  void _handleCursorMove(int line, int column) {
    tabManager.getScrollManager(core!.path).jumpToCursor(
          core!,
          tabManager
              .getScrollManager(core!.path)
              .editorVerticalScrollController
              .position
              .viewportDimension,
          tabManager
              .getScrollManager(core!.path)
              .editorHorizontalScrollController
              .position
              .viewportDimension,
        );
  }

  void _forceRefresh() {
    setState(() {
      // Recalculate scroll positions
      scrollManager.recalculateScrollPosition(
        core!,
        scrollManager.editorVerticalScrollController.position.viewportDimension,
        scrollManager
            .editorHorizontalScrollController.position.viewportDimension,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
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
                TabBar(
                  tabAlignment: TabAlignment.start,
                  controller: tabManager.controller,
                  isScrollable: true,
                  tabs: tabManager.tabs.map((path) {
                    return Tab(
                      child: Row(
                        children: [
                          Text(path.split(Platform.pathSeparator).last),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            onPressed: () => tabManager.closeTab(path),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
                Expanded(
                    child: Row(children: [
                  if (core != null)
                    Gutter(
                      core: core!,
                      verticalScrollController: tabManager
                          .getScrollManager(core!.path)
                          .gutterVerticalScrollController,
                      tabBarHeight: tabBarHeight,
                    ),
                  Expanded(
                    child: TabBarView(
                      controller: tabManager.controller,
                      children: tabManager.tabs.map((path) {
                        final scrollManager = tabManager.getScrollManager(path);
                        return Editor(
                          onCoreInitialized: _handleEditorCore,
                          verticalScrollController:
                              scrollManager.editorVerticalScrollController,
                          horizontalScrollController:
                              scrollManager.editorHorizontalScrollController,
                          path: path,
                          tabBarHeight: tabBarHeight,
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
  }
}
