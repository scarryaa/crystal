import 'dart:ui';

import 'package:crystal/models/editor/commands/search_config.dart';
import 'package:crystal/models/editor/config/completion_config.dart';
import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/config/file_config.dart';
import 'package:crystal/models/editor/config/scroll_config.dart';
import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/models/global_hover_state.dart';
import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_services.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/services/search_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_control_bar_view.dart';
import 'package:crystal/widgets/editor/editor_tab_bar.dart';
import 'package:crystal/widgets/editor/editor_view.dart';
import 'package:crystal/widgets/editor/minimap.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';

class EditorSection extends StatelessWidget {
  final SplitView splitView;
  final int row;
  final int col;
  final EditorConfigService editorConfigService;
  final EditorTabManager editorTabManager;
  final SearchService searchService;
  final Function(int, {int? row, int? col}) onActiveEditorChanged;
  final Function(int, {int? row, int? col}) onEditorClosed;
  final Function({int? row, int? col}) openNewTab;
  final Function(int, int) scrollToCursor;
  final FileService fileService;
  final Function(String)? onDirectoryChanged;
  final int selectedSuggestionIndex;
  final GitService gitService;
  final GlobalHoverState globalHoverState;

  const EditorSection({
    super.key,
    required this.splitView,
    required this.row,
    required this.col,
    required this.editorConfigService,
    required this.editorTabManager,
    required this.searchService,
    required this.onActiveEditorChanged,
    required this.onEditorClosed,
    required this.openNewTab,
    required this.scrollToCursor,
    required this.fileService,
    required this.onDirectoryChanged,
    required this.selectedSuggestionIndex,
    required this.gitService,
    required this.globalHoverState,
  });

  @override
  Widget build(BuildContext context) {
    return _buildEditorSection(context, splitView, row, col);
  }

  Widget _buildEditorSection(
      BuildContext context, SplitView splitView, int row, int col) {
    final editorState = Provider.of<EditorStateProvider>(context);
    final scrollManager = editorState.getScrollManager(row, col);
    final editorViewKey = editorState.getEditorViewKey(row, col);
    final tabBarKey = editorState.getTabBarKey(row, col);
    final tabBarScrollController =
        editorState.getTabBarScrollController(row, col);
    final totalContentHeight = splitView.activeEditor?.buffer.lines.length ??
        0 * EditorLayoutService.instance.config.lineHeight;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EditorState?>.value(
          value: splitView.activeEditor,
        ),
      ],
      child: Consumer<EditorState?>(
        builder: (context, state, _) {
          return MouseRegion(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                if (row < editorTabManager.horizontalSplits.length &&
                    col < editorTabManager.horizontalSplits[row].length) {
                  editorTabManager.focusSplitView(row, col);
                  if (splitView.activeEditorIndex >= 0) {
                    onActiveEditorChanged(
                      splitView.activeEditorIndex,
                      row: row,
                      col: col,
                    );
                  }
                }
              },
              onPointerPanZoomStart: (_) {
                editorTabManager.focusSplitView(row, col);
                if (splitView.activeEditorIndex >= 0) {
                  onActiveEditorChanged(
                    splitView.activeEditorIndex,
                    row: row,
                    col: col,
                  );
                }
              },
              onPointerPanZoomUpdate: (_) {
                editorTabManager.focusSplitView(row, col);
                if (splitView.activeEditorIndex >= 0) {
                  onActiveEditorChanged(
                    splitView.activeEditorIndex,
                    row: row,
                    col: col,
                  );
                }
              },
              onPointerMove: (event) {
                if (event.kind == PointerDeviceKind.touch) {
                  editorTabManager.focusSplitView(row, col);
                  onActiveEditorChanged(
                    splitView.activeEditorIndex,
                    row: row,
                    col: col,
                  );
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: editorConfigService
                          .themeService.currentTheme?.background ??
                      Colors.white,
                ),
                child: Column(
                  children: [
                    if (splitView.editors.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: EditorTabBar(
                              tabScrollKey: tabBarKey,
                              onPin: (index) => editorTabManager.togglePin(
                                index,
                                row: row,
                                col: col,
                              ),
                              onCloseTabsToRight: (index) => editorTabManager
                                  .closeTabsToRight(index, row: row, col: col),
                              onCloseTabsToLeft: (index) => editorTabManager
                                  .closeTabsToLeft(index, row: row, col: col),
                              onCloseOtherTabs: (index) => editorTabManager
                                  .closeOtherTabs(index, row: row, col: col),
                              editorConfigService: editorConfigService,
                              editors: splitView.editors,
                              activeEditorIndex: splitView.activeEditorIndex,
                              onActiveEditorChanged: (index) =>
                                  onActiveEditorChanged(
                                index,
                                row: row,
                                col: col,
                              ),
                              onEditorClosed: (index) => onEditorClosed(
                                index,
                                row: row,
                                col: col,
                              ),
                              onReorder: (oldIndex, newIndex) =>
                                  editorTabManager.reorderEditor(
                                oldIndex,
                                newIndex,
                                row: row,
                                col: col,
                              ),
                              onNewTab: () => openNewTab(row: row, col: col),
                              onSplitHorizontal: () =>
                                  editorTabManager.addHorizontalSplit(),
                              onSplitVertical: () =>
                                  editorTabManager.addVerticalSplit(),
                              row: row,
                              col: col,
                              onSplitClose: () =>
                                  editorTabManager.closeSplitView(row, col),
                              editorTabManager: editorTabManager,
                              tabBarScrollController: tabBarScrollController,
                              onDirectoryChanged: onDirectoryChanged,
                              fileService: fileService,
                              gitService: gitService,
                            ),
                          ),
                        ],
                      ),
                    if (splitView.editors.isNotEmpty)
                      EditorControlBarView(
                        editorConfigService: editorConfigService,
                        filePath: state?.relativePath ?? state?.path ?? '',
                        searchTermChanged: (newTerm) =>
                            searchService.onSearchTermChanged(newTerm, state),
                        nextSearchTerm: () =>
                            searchService.nextSearchTerm(state),
                        previousSearchTerm: () =>
                            searchService.previousSearchTerm(state),
                        currentSearchTermMatch:
                            searchService.currentSearchTermMatch,
                        totalSearchTermMatches:
                            searchService.searchTermMatches.length,
                        isCaseSensitiveActive:
                            searchService.caseSensitiveActive,
                        isRegexActive: searchService.regexActive,
                        isWholeWordActive: searchService.wholeWordActive,
                        toggleRegex: (active) =>
                            searchService.toggleRegex(active, state),
                        toggleWholeWord: (active) =>
                            searchService.toggleWholeWord(active, state),
                        toggleCaseSensitive: (active) =>
                            searchService.toggleCaseSensitive(active, state),
                        replaceNextMatch: (newTerm) =>
                            searchService.replaceNextMatch(newTerm, state),
                        replaceAllMatches: (newTerm) =>
                            searchService.replaceAllMatches(newTerm, state),
                        editorState: state!,
                        scrollToCursor: () => scrollToCursor(row, col),
                      ),
                    Expanded(
                      child: Container(
                        color: editorConfigService
                                .themeService.currentTheme?.background ??
                            Colors.white,
                        child: Row(
                          children: [
                            if (splitView.editors.isNotEmpty && state != null)
                              Gutter(
                                editorConfigService: editorConfigService,
                                editorLayoutService:
                                    EditorLayoutService.instance,
                                editorState: state,
                                verticalScrollController:
                                    scrollManager.gutterScrollController,
                                onFoldToggled: () {
                                  WidgetsBinding.instance
                                      .addPostFrameCallback((_) {
                                    scrollManager.editorVerticalScrollController
                                        .jumpTo(scrollManager
                                            .editorVerticalScrollController
                                            .offset);
                                    state.updateVerticalScrollOffset(
                                        scrollManager
                                            .editorVerticalScrollController
                                            .offset);
                                  });
                                },
                                gitService: gitService,
                              ),
                            Expanded(
                              child: splitView.editors.isNotEmpty &&
                                      splitView.activeEditor != null
                                  ? ValueListenableBuilder<int>(
                                      valueListenable: splitView.activeEditor!
                                          .selectedSuggestionIndexNotifier,
                                      builder: (context, selectedIndex, _) {
                                        return EditorView(
                                          key: editorViewKey,
                                          config: EditorViewConfig(
                                            row: row,
                                            col: col,
                                            scrollConfig: ScrollConfig(
                                              verticalController: scrollManager
                                                  .editorVerticalScrollController,
                                              horizontalController: scrollManager
                                                  .editorHorizontalScrollController,
                                              scrollToCursor: () =>
                                                  scrollToCursor(row, col),
                                            ),
                                            fileConfig: FileConfig(
                                              fileName: path
                                                  .split(splitView
                                                      .activeEditor!.path)
                                                  .last,
                                              isDirty: splitView.activeEditor
                                                      ?.buffer.isDirty ??
                                                  false,
                                              onEditorClosed: onEditorClosed,
                                              saveFileAs: () => splitView
                                                  .activeEditor!
                                                  .saveFileAs(splitView
                                                      .activeEditor!.path),
                                              saveFile: () => splitView
                                                  .activeEditor!
                                                  .saveFile(splitView
                                                      .activeEditor!.path),
                                              openNewTab: openNewTab,
                                              activeEditorIndex: () =>
                                                  splitView.activeEditorIndex,
                                            ),
                                            searchConfig: SearchConfig(
                                              searchTerm:
                                                  searchService.searchTerm,
                                              matches: searchService
                                                  .searchTermMatches,
                                              currentMatch: searchService
                                                  .currentSearchTermMatch,
                                              onSearchTermChanged: (newTerm) =>
                                                  searchService
                                                      .updateSearchMatches(
                                                          newTerm,
                                                          splitView
                                                              .activeEditor),
                                            ),
                                            completionConfig: CompletionConfig(
                                              suggestions: editorTabManager
                                                      .activeEditor
                                                      ?.suggestions ??
                                                  [],
                                              selectedIndex: selectedIndex,
                                              onSelect: (item) {
                                                editorTabManager.activeEditor
                                                    ?.acceptCompletion(item);
                                              },
                                            ),
                                            services: EditorServices(
                                              configService:
                                                  editorConfigService,
                                              layoutService:
                                                  EditorLayoutService.instance,
                                              gitService: gitService,
                                            ),
                                            state: splitView.activeEditor!,
                                            globalHoverState: globalHoverState,
                                          ),
                                        );
                                      })
                                  : Container(
                                      color: editorConfigService.themeService
                                              .currentTheme?.background ??
                                          Colors.white,
                                    ),
                            ),
                            if (splitView.editors.isNotEmpty &&
                                splitView.activeEditor != null)
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  return Minimap(
                                      buffer: splitView.activeEditor!.buffer,
                                      viewportHeight: constraints.maxHeight,
                                      scrollPosition: scrollManager
                                              .editorVerticalScrollController
                                              .hasClients
                                          ? scrollManager
                                              .editorVerticalScrollController
                                              .position
                                              .pixels
                                          : 0.0,
                                      layoutService:
                                          EditorLayoutService.instance,
                                      editorConfigService: editorConfigService,
                                      onScroll: (position) {
                                        if (scrollManager
                                            .editorVerticalScrollController
                                            .hasClients) {
                                          scrollManager
                                              .editorVerticalScrollController
                                              .jumpTo(position);
                                        }
                                      },
                                      totalContentHeight:
                                          totalContentHeight.toDouble(),
                                      fileName: path
                                          .split(splitView.activeEditor!.path)
                                          .last);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
