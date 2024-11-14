import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/screens/editor/file_explorer/file_explorer_container.dart';
import 'package:crystal/screens/editor/terminal/terminal_section.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_scroll_manager.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/search_service.dart';
import 'package:crystal/services/shortcut_handler.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_control_bar_view.dart';
import 'package:crystal/widgets/editor/editor_tab_bar.dart';
import 'package:crystal/widgets/editor/editor_view.dart';
import 'package:crystal/widgets/editor/resizable_split_container.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:crystal/widgets/status_bar/status_bar.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorScreen extends StatefulWidget {
  final double horizontalPadding;
  final int verticalPaddingLines;
  final double lineHeightMultipler;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;

  const EditorScreen({
    super.key,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultipler,
    required this.onDirectoryChanged,
    required this.fileService,
  });

  @override
  State<StatefulWidget> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  final Map<String, GlobalKey> _tabBarKeys = {};
  final Map<int, GlobalKey<EditorViewState>> _editorViewKeys = {};
  late final EditorConfigService _editorConfigService;
  late final EditorTabManager editorTabManager;
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  late SearchService searchService;
  final Map<int, EditorScrollManager> _scrollManagers = {};
  final Map<String, ScrollController> _tabBarScrollControllers = {};

  ScrollController _getTabBarScrollController(int row, int col) {
    final String key = 'tabBar_${row}_$col';
    if (!_tabBarScrollControllers.containsKey(key)) {
      _tabBarScrollControllers[key] = ScrollController();
    }
    return _tabBarScrollControllers[key]!;
  }

  GlobalKey _getTabBarKey(int row, int col) {
    final String keyId = 'tabBar_${row}_$col';
    return _tabBarKeys.putIfAbsent(keyId, () => GlobalKey());
  }

  void scrollToTab(int index) {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = editorTabManager.activeRow;
      final col = editorTabManager.activeCol;
      final splitView =
          editorTabManager.horizontalSplits[editorTabManager.activeRow]
              [editorTabManager.activeCol];

      if (index < 0 || index >= splitView.editors.length) return;

      final tabBarKey =
          _getTabBarKey(editorTabManager.activeRow, editorTabManager.activeCol);
      final tabBarContext = tabBarKey.currentContext;
      if (tabBarContext == null) return;

      final scrollController = _getTabBarScrollController(row, col);
      final double maxScroll = scrollController.position.maxScrollExtent;

      double totalWidth = 0;
      for (int i = 0; i < index; i++) {
        final element = splitView.editors[i];
        final tabWidth = _calculateTabWidth(element);
        totalWidth += tabWidth;
      }

      final double constrainedScroll = totalWidth.clamp(0.0, maxScroll);

      scrollController.animateTo(
        constrainedScroll,
        duration: const Duration(milliseconds: 1),
        curve: Curves.easeInOut,
      );
    });
  }

  double _calculateTabWidth(EditorState editor) {
    final textSpan = TextSpan(
        text: editor.relativePath ?? editor.path,
        style: TextStyle(fontSize: _editorConfigService.config.fontSize));
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    return textPainter.width + 60;
  }

  EditorScrollManager _getScrollManager(int row, int col) {
    final splitIndex = getSplitIndex(row, col);

    if (!_scrollManagers.containsKey(splitIndex)) {
      final scrollManager = EditorScrollManager();
      scrollManager.initListeners(
        onEditorScroll: () => _handleEditorScroll(row, col),
        onGutterScroll: () => _handleGutterScroll(row, col),
      );
      _scrollManagers[splitIndex] = scrollManager;
    }
    return _scrollManagers[splitIndex]!;
  }

  GlobalKey<EditorViewState> _getEditorViewKey(int splitViewIndex) {
    return _editorViewKeys.putIfAbsent(
      splitViewIndex,
      () => GlobalKey<EditorViewState>(),
    );
  }

  void openNewTab({int? row, int? col}) {
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;
    final scrollManager = _getScrollManager(targetRow, targetCol);

    // Focus the target split view first
    editorTabManager.focusSplitView(targetRow, targetCol);

    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: () => scrollManager.resetGutterScroll(),
      tapCallback: tapCallback,
      onDirectoryChanged: widget.onDirectoryChanged,
      fileService: widget.fileService,
    );

    editorTabManager.addEditor(newEditor, row: targetRow, col: targetCol);

    setState(() {
      editorTabManager.activeEditor!.openFile('');
      searchService.onSearchTermChanged(
          searchService.searchTerm, editorTabManager.activeEditor);
    });

    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null) {
        editorKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  Future<void> tapCallback(String path, {int? row, int? col}) async {
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Check if file is already open in the current split
    final editorIndex = editorTabManager
        .horizontalSplits[targetRow][targetCol].editors
        .indexWhere((editor) => editor.path == path);

    if (editorIndex != -1) {
      // File is already open in current split, just focus it
      editorTabManager.focusSplitView(targetRow, targetCol);
      onActiveEditorChanged(editorIndex, row: targetRow, col: targetCol);
      scrollToTab(editorIndex);
      return;
    }

    // File is not open in current split, create new editor
    final scrollManager = _getScrollManager(targetRow, targetCol);
    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));

    String content = await File(path).readAsString();
    final relativePath = widget.fileService
        .getRelativePath(path, widget.fileService.rootDirectory);

    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: () => scrollManager.resetGutterScroll(),
      path: path,
      relativePath: relativePath,
      tapCallback: tapCallback,
      onDirectoryChanged: widget.onDirectoryChanged,
      fileService: widget.fileService,
    );

    editorTabManager.focusSplitView(targetRow, targetCol);

    setState(() {
      editorTabManager.addEditor(newEditor, row: targetRow, col: targetCol);
      editorTabManager.activeEditor!.openFile(content);
    });

    searchService.updateSearchMatches(
      searchService.searchTerm,
      editorTabManager.activeEditor,
    );

    // Get the new editor's index after adding it
    final newEditorIndex =
        editorTabManager.horizontalSplits[targetRow][targetCol].editors.length -
            1;
    scrollToTab(newEditorIndex);

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => editorKey.currentState!.updateCachedMaxLineWidth());
  }

  @override
  void initState() {
    super.initState();
    editorTabManager = EditorTabManager(
      onSplitViewClosed: _cleanupScrollManager,
      onDirectoryChanged: widget.onDirectoryChanged,
      fileService: widget.fileService,
    );
    _initializationFuture = _initializeServices();
    searchService = SearchService(
      scrollToCursor: () => _scrollToCursor(
        editorTabManager.activeRow,
        editorTabManager.activeCol,
      ),
    );

    // Initialize scroll manager for the first split view
    _getScrollManager(0, 0);
  }

  void _cleanupScrollManager(int row, int col) {
    final splitIndex = getSplitIndex(row, col);
    if (_scrollManagers.containsKey(splitIndex)) {
      _scrollManagers[splitIndex]!.dispose();
      _scrollManagers.remove(splitIndex);
    }

    // Remap remaining scroll managers
    final newScrollManagers = <int, EditorScrollManager>{};
    for (int r = 0; r < editorTabManager.horizontalSplits.length; r++) {
      for (int c = 0; c < editorTabManager.horizontalSplits[r].length; c++) {
        final oldIndex = getSplitIndex(r, c);
        final newIndex = getSplitIndex(r, c);
        if (_scrollManagers.containsKey(oldIndex)) {
          newScrollManagers[newIndex] = _scrollManagers[oldIndex]!;
        }
      }
    }
    _scrollManagers
      ..clear()
      ..addAll(newScrollManagers);
  }

  void _handleEditorScroll(int row, int col) {
    // Validate indices before accessing splits
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = _getScrollManager(row, col);
    final activeEditor =
        editorTabManager.horizontalSplits[row][col].activeEditor;

    if (activeEditor == null) return;

    if (scrollManager.gutterScrollController.offset !=
        scrollManager.editorVerticalScrollController.offset) {
      scrollManager.gutterScrollController
          .jumpTo(scrollManager.editorVerticalScrollController.offset);
      activeEditor.updateVerticalScrollOffset(
          scrollManager.editorVerticalScrollController.offset);
    }

    activeEditor.updateHorizontalScrollOffset(
        scrollManager.editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll(int row, int col) {
    // Validate indices before accessing splits
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = _getScrollManager(row, col);
    final activeEditor =
        editorTabManager.horizontalSplits[row][col].activeEditor;

    if (activeEditor == null) return;

    if (scrollManager.editorVerticalScrollController.offset !=
        scrollManager.gutterScrollController.offset) {
      scrollManager.editorVerticalScrollController
          .jumpTo(scrollManager.gutterScrollController.offset);
      activeEditor.updateVerticalScrollOffset(
          scrollManager.gutterScrollController.offset);
    }
  }

  void _scrollToCursor(int row, int col) {
    // Validate indices before proceeding
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = _getScrollManager(row, col);
    final activeEditor =
        editorTabManager.horizontalSplits[row][col].activeEditor;

    if (activeEditor == null) return;

    scrollManager.scrollToCursor(
      activeEditor: activeEditor,
      layoutService: EditorLayoutService.instance,
    );
  }

  Future<void> _initializeServices() async {
    _editorConfigService = await EditorConfigService.create();

    EditorLayoutService(
      horizontalPadding: widget.horizontalPadding,
      verticalPaddingLines: widget.verticalPaddingLines,
      gutterWidth: 60,
      fontSize: _editorConfigService.config.fontSize,
      fontFamily: _editorConfigService.config.fontFamily,
      lineHeightMultiplier: widget.lineHeightMultipler,
    );

    EditorLayoutService.instance.updateFontSize(
        _editorConfigService.config.fontSize,
        _editorConfigService.config.fontFamily);

    _editorConfigService.addListener(_onConfigChanged);

    _shortcutHandler = ShortcutHandler(
      openSettings: _openSettings,
      openDefaultSettings: _openDefaultSettings,
      closeTab: () {
        if (editorTabManager.activeSplitView.activeEditorIndex >= 0) {
          onEditorClosed(editorTabManager.activeSplitView.activeEditorIndex);
        }
      },
      openNewTab: () {
        openNewTab();
      },
      saveFile: () async {
        if (editorTabManager.activeEditor != null) {
          await editorTabManager.activeEditor!
              .saveFile(editorTabManager.activeEditor!.path);
        }
        return Future<void>.value();
      },
      saveFileAs: () async {
        if (editorTabManager.activeEditor != null) {
          await editorTabManager.activeEditor!
              .saveFileAs(editorTabManager.activeEditor!.path);
        }
        return Future<void>.value();
      },
      requestEditorFocus: () {
        if (editorTabManager.activeEditor != null) {
          editorTabManager.activeEditor!.requestFocus();
        }
      },
    );
  }

  void _onConfigChanged() {
    EditorLayoutService.instance.updateFontSize(
      _editorConfigService.config.fontSize,
      _editorConfigService.config.fontFamily,
    );

    if (mounted) {
      setState(() {
        for (int i = 0; i < editorTabManager.editors.length; i++) {
          if (editorTabManager.editors[i].path.endsWith('editor_config.json')) {
            // Reload the settings file if it is open
            editorTabManager.editors[i].buffer.setContent(
                FileService.readFile(editorTabManager.editors[i].path));
          }
        }
      });
    }
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void onActiveEditorChanged(int index, {int? row, int? col}) {
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Validate indices before proceeding
    if (targetRow >= editorTabManager.horizontalSplits.length ||
        targetCol >= editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = _getScrollManager(targetRow, targetCol);
    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));

    setState(() {
      editorTabManager.setActiveEditor(
        index,
        row: targetRow,
        col: targetCol,
      );

      if (editorTabManager.activeEditor != null) {
        scrollManager.editorVerticalScrollController
            .jumpTo(editorTabManager.activeEditor!.scrollState.verticalOffset);
        scrollManager.editorHorizontalScrollController.jumpTo(
            editorTabManager.activeEditor!.scrollState.horizontalOffset);
        searchService.updateSearchMatches(
          searchService.searchTerm,
          editorTabManager.activeEditor,
        );
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null) {
        editorKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  void onEditorClosed(int index, {int? row, int? col}) {
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Early validation
    if (targetRow >= editorTabManager.horizontalSplits.length ||
        targetCol >= editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = _getScrollManager(targetRow, targetCol);
    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));

    setState(() {
      final verticalOffset =
          editorTabManager.activeEditor?.scrollState.verticalOffset ?? 0.0;
      final horizontalOffset =
          editorTabManager.activeEditor?.scrollState.horizontalOffset ?? 0.0;

      editorTabManager.closeEditor(
        index,
        row: targetRow,
        col: targetCol,
      );

      // Only update scroll positions if there's still an active editor
      scrollManager.editorVerticalScrollController.jumpTo(verticalOffset);
      scrollManager.editorHorizontalScrollController.jumpTo(horizontalOffset);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null && mounted) {
        editorKey.currentState!.updateCachedMaxLineWidth();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    for (final scrollManager in _scrollManagers.values) {
      scrollManager.dispose();
    }
    for (final scrollController in _tabBarScrollControllers.values) {
      scrollController.dispose();
    }
    _scrollManagers.clear();
    _editorConfigService.themeService.removeListener(_onThemeChanged);
    _editorConfigService.removeListener(_onConfigChanged);
    super.dispose();
  }

  Future<void> _openSettings() async {
    await tapCallback(await ConfigPaths.getConfigFilePath());
  }

  Future<void> _openDefaultSettings() async {
    await tapCallback(await ConfigPaths.getDefaultConfigFilePath());
  }

  int getSplitIndex(int row, int col) {
    int index = 0;
    for (int i = 0; i < row; i++) {
      index += editorTabManager.horizontalSplits[i].length;
    }
    return index + col;
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider.value(
            value: _editorConfigService,
          ),
          ChangeNotifierProvider(
            create: (_) => FileExplorerProvider(
              configService: _editorConfigService,
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => TerminalProvider(
              editorConfigService: _editorConfigService,
            ),
          ),
        ],
        child: FutureBuilder(
          future: _initializationFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            return MultiProvider(
                providers: [
                  ChangeNotifierProvider(
                    create: (_) => FileExplorerProvider(
                      configService: _editorConfigService,
                    ),
                  ),
                  ChangeNotifierProvider(
                    create: (_) => TerminalProvider(
                      editorConfigService: _editorConfigService,
                    ),
                  ),
                ],
                child: ListenableBuilder(
                  listenable: Listenable.merge(
                      [_editorConfigService, editorTabManager]),
                  builder: (context, child) {
                    bool isFileExplorerOnLeft =
                        _editorConfigService.config.isFileExplorerOnLeft;

                    return Focus(
                      autofocus: true,
                      onKeyEvent: (node, event) =>
                          _shortcutHandler.handleKeyEvent(node, event),
                      child: Material(
                        child: Column(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  if (isFileExplorerOnLeft)
                                    FileExplorerContainer(
                                        editorConfigService:
                                            _editorConfigService,
                                        fileService: widget.fileService,
                                        tapCallback: tapCallback,
                                        onDirectoryChanged:
                                            widget.onDirectoryChanged),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child:
                                              editorTabManager
                                                      .horizontalSplits.isEmpty
                                                  ? Container()
                                                  : ResizableSplitContainer(
                                                      direction: Axis.vertical,
                                                      initialSizes:
                                                          List.generate(
                                                        editorTabManager
                                                            .horizontalSplits
                                                            .length,
                                                        (index) =>
                                                            1.0 /
                                                            editorTabManager
                                                                .horizontalSplits
                                                                .length,
                                                      ),
                                                      onSizesChanged: (sizes) =>
                                                          editorTabManager
                                                              .updateVerticalSizes(
                                                                  sizes),
                                                      editorConfigService:
                                                          _editorConfigService,
                                                      children: List.generate(
                                                        editorTabManager
                                                            .horizontalSplits
                                                            .length,
                                                        (row) {
                                                          return editorTabManager
                                                                  .horizontalSplits[
                                                                      row]
                                                                  .isEmpty
                                                              ? Container()
                                                              : ResizableSplitContainer(
                                                                  direction: Axis
                                                                      .horizontal,
                                                                  initialSizes:
                                                                      List.generate(
                                                                    editorTabManager
                                                                        .horizontalSplits[
                                                                            row]
                                                                        .length,
                                                                    (index) =>
                                                                        1.0 /
                                                                        editorTabManager
                                                                            .horizontalSplits[row]
                                                                            .length,
                                                                  ),
                                                                  onSizesChanged:
                                                                      (sizes) =>
                                                                          editorTabManager.updateHorizontalSizes(
                                                                              row,
                                                                              sizes),
                                                                  editorConfigService:
                                                                      _editorConfigService,
                                                                  children: List
                                                                      .generate(
                                                                    editorTabManager
                                                                        .horizontalSplits[
                                                                            row]
                                                                        .length,
                                                                    (col) =>
                                                                        _buildEditorSection(
                                                                      editorTabManager
                                                                              .horizontalSplits[row]
                                                                          [col],
                                                                      row,
                                                                      col,
                                                                    ),
                                                                  ),
                                                                );
                                                        },
                                                      ),
                                                    ),
                                        ),
                                        TerminalSection(
                                            editorConfigService:
                                                _editorConfigService),
                                      ],
                                    ),
                                  ),
                                  if (!isFileExplorerOnLeft)
                                    FileExplorerContainer(
                                        editorConfigService:
                                            _editorConfigService,
                                        fileService: widget.fileService,
                                        tapCallback: tapCallback,
                                        onDirectoryChanged:
                                            widget.onDirectoryChanged),
                                ],
                              ),
                            ),
                            const StatusBar(),
                          ],
                        ),
                      ),
                    );
                  },
                ));
          },
        ));
  }

  Widget _buildEditorSection(SplitView splitView, int row, int col) {
    final scrollManager = _getScrollManager(row, col);
    final editorViewKey = _getEditorViewKey(getSplitIndex(row, col));
    final tabBarKey = _getTabBarKey(row, col);
    final tabBarScrollController = _getTabBarScrollController(row, col);

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
                  // Check if indices are still valid before focusing
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
                    color: _editorConfigService
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
                                editorConfigService: _editorConfigService,
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
                                onDirectoryChanged: widget.onDirectoryChanged,
                                fileService: widget.fileService,
                              ),
                            ),
                          ],
                        ),
                      if (splitView.editors.isNotEmpty)
                        EditorControlBarView(
                          editorConfigService: _editorConfigService,
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
                        ),
                      Expanded(
                        child: Container(
                          color: _editorConfigService
                                  .themeService.currentTheme?.background ??
                              Colors.white,
                          child: Row(
                            children: [
                              if (splitView.editors.isNotEmpty && state != null)
                                Gutter(
                                  editorConfigService: _editorConfigService,
                                  editorLayoutService:
                                      EditorLayoutService.instance,
                                  editorState: state,
                                  verticalScrollController:
                                      scrollManager.gutterScrollController,
                                  onFoldToggled: () {
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                      scrollManager
                                          .editorVerticalScrollController
                                          .jumpTo(scrollManager
                                              .editorVerticalScrollController
                                              .offset);
                                      state.updateVerticalScrollOffset(
                                          scrollManager
                                              .editorVerticalScrollController
                                              .offset);
                                    });
                                  },
                                ),
                              Expanded(
                                child: splitView.editors.isNotEmpty &&
                                        splitView.activeEditor != null
                                    ? EditorView(
                                        key: editorViewKey,
                                        editorConfigService:
                                            _editorConfigService,
                                        editorLayoutService:
                                            EditorLayoutService.instance,
                                        state: splitView.activeEditor!,
                                        searchTerm: searchService.searchTerm,
                                        searchTermMatches:
                                            searchService.searchTermMatches,
                                        currentSearchTermMatch: searchService
                                            .currentSearchTermMatch,
                                        onSearchTermChanged: (newTerm) =>
                                            searchService.updateSearchMatches(
                                                newTerm,
                                                splitView.activeEditor),
                                        scrollToCursor: () =>
                                            _scrollToCursor(row, col),
                                        onEditorClosed: onEditorClosed,
                                        saveFileAs: () =>
                                            splitView.activeEditor!.saveFileAs(
                                                splitView.activeEditor!.path),
                                        saveFile: () => splitView.activeEditor!
                                            .saveFile(
                                                splitView.activeEditor!.path),
                                        openNewTab: openNewTab,
                                        activeEditorIndex: () =>
                                            splitView.activeEditorIndex,
                                        verticalScrollController: scrollManager
                                            .editorVerticalScrollController,
                                        horizontalScrollController: scrollManager
                                            .editorHorizontalScrollController,
                                      )
                                    : Container(
                                        color: _editorConfigService.themeService
                                                .currentTheme?.background ??
                                            Colors.white,
                                      ),
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
        ));
  }
}
