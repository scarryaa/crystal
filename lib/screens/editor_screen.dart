import 'dart:io';

import 'package:crystal/core/editor/editor_config.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor.dart';
import 'package:crystal/widgets/editor/managers/editor_content_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_scroll_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_state_manager.dart';
import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:crystal/widgets/editor/tabs/custom_tab_bar.dart';
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
import 'package:crystal/widgets/file_explorer/viewmodel/file_explorer_view_model.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen>
    with TickerProviderStateMixin {
  EditorScrollManager scrollManager = EditorScrollManager();

  late final EditorContentManager contentManager;
  late final EditorStateManager stateManager;
  late final EditorTabController tabController;

  late final FileExplorerViewModel fileExplorerViewModel;
  final tabBarHeight = 32.0;
  final tabBarPadding = 4.0;
  double _gutterWidth = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    EditorConfig().ensureDefaultAndRegularConfig();

    fileExplorerViewModel = FileExplorerViewModel();
    contentManager = EditorContentManager();
    stateManager = EditorStateManager(contentManager: contentManager);
    tabController = EditorTabController(
        vsync: this,
        stateManager: stateManager,
        contentManager: contentManager);

    contentManager.setTabController(tabController);
    stateManager.setTabController(tabController);
  }

  Future<String> getConfigPath({bool defaultConfig = false}) async {
    final configDir = await EditorConfig().getConfigDirectory();
    return defaultConfig
        ? '$configDir/default_config.json'
        : '$configDir/config.json';
  }

  void openFile(String path) {
    final file = File(path);
    file.readAsString().then((content) {
      setState(() {
        tabController.openTab(EditorScrollManager(), path, content);
      });
    });
  }

  void _handleEditorCore(EditorCore core, String path) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        stateManager.registerCore(path, core);
      });
    });
  }

  void updatePath(String oldPath, String newPath) {
    tabController.updatePath(oldPath, newPath);
  }

  @override
  void dispose() {
    scrollManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
        bindings: {
          if (!Platform.isMacOS)
            const SingleActivator(LogicalKeyboardKey.comma, control: true):
                _openConfigFile,
          if (!Platform.isMacOS)
            const SingleActivator(LogicalKeyboardKey.less,
                shift: true, control: true): _openDefaultConfigFile,
          if (Platform.isMacOS)
            const SingleActivator(LogicalKeyboardKey.comma, meta: true):
                _openConfigFile,
          if (Platform.isMacOS)
            const SingleActivator(LogicalKeyboardKey.less,
                shift: true, meta: true): _openDefaultConfigFile,
        },
        child: GestureDetector(
            onTap: () => _focusNode.requestFocus,
            child: Focus(
                focusNode: _focusNode,
                autofocus: true,
                child: ListenableBuilder(
                    listenable: Listenable.merge([tabController, stateManager]),
                    builder: (context, child) {
                      final currentPath = tabController.getCurrentPath();
                      final activeCore = stateManager.getActiveCore();

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
                                    tabController: tabController,
                                  ),
                                  Expanded(
                                      child: tabController.tabs.isNotEmpty
                                          ? Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                  if (activeCore != null &&
                                                      currentPath != null)
                                                    Gutter(
                                                      key: ValueKey(currentPath
                                                              .isNotEmpty
                                                          ? '${currentPath}_gutter'
                                                          : null),
                                                      core: activeCore,
                                                      verticalScrollController:
                                                          stateManager
                                                              .getScrollManager(
                                                                  currentPath)
                                                              .gutterVerticalScrollController,
                                                      tabBarHeight:
                                                          tabBarHeight +
                                                              tabBarPadding,
                                                      onWidthChanged: (width) {
                                                        WidgetsBinding.instance
                                                            .addPostFrameCallback(
                                                                (_) => setState(() =>
                                                                    _gutterWidth =
                                                                        width));
                                                      },
                                                    ),
                                                  if (currentPath != null)
                                                    Expanded(
                                                      child: TabBarView(
                                                        key: ValueKey(currentPath
                                                                .isNotEmpty
                                                            ? '${currentPath}_gutter'
                                                            : null),
                                                        physics:
                                                            const NeverScrollableScrollPhysics(),
                                                        controller:
                                                            tabController
                                                                .controller,
                                                        children: tabController
                                                            .tabs
                                                            .map((path) {
                                                          final scrollManager =
                                                              stateManager
                                                                  .getScrollManager(
                                                                      path);
                                                          return Editor(
                                                            stateManager:
                                                                stateManager,
                                                            focusNode: stateManager
                                                                    .focusNodes[
                                                                path]!,
                                                            fileExplorerWidth:
                                                                fileExplorerViewModel
                                                                    .width,
                                                            gutterWidth:
                                                                _gutterWidth,
                                                            onCoreInitialized:
                                                                (core) =>
                                                                    _handleEditorCore(
                                                                        core,
                                                                        path),
                                                            verticalScrollController:
                                                                scrollManager
                                                                    .editorVerticalScrollController,
                                                            horizontalScrollController:
                                                                scrollManager
                                                                    .editorHorizontalScrollController,
                                                            path: path,
                                                            tabBarHeight:
                                                                tabBarHeight +
                                                                    tabBarPadding,
                                                            openFile: (path) =>
                                                                openFile(path),
                                                            openConfigFile:
                                                                _openConfigFile,
                                                            openDefaultConfigFile:
                                                                _openDefaultConfigFile,
                                                            updatePath:
                                                                updatePath,
                                                          );
                                                        }).toList(),
                                                      ),
                                                    ),
                                                ])
                                          : Container(
                                              color: Colors.white,
                                            ))
                                ])),
                              ],
                            ),
                          ),
                        ],
                      ));
                    }))));
  }

  Future<void> _openDefaultConfigFile() async {
    final configPath = await getConfigPath(defaultConfig: true);
    openFile(configPath);
  }

  Future<void> _openConfigFile() async {
    final configPath = await getConfigPath();
    openFile(configPath);
  }
}
