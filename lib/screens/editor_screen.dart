import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/split_view.dart';
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
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
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
  final Function()? onDirectoryRefresh;
  final FileService fileService;

  const EditorScreen({
    super.key,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultipler,
    required this.onDirectoryChanged,
    required this.onDirectoryRefresh,
    required this.fileService,
  });

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _isFileExplorerVisible = true;
  final Map<int, GlobalKey<EditorViewState>> _editorViewKeys = {};
  late final EditorConfigService _editorConfigService;
  late final EditorTabManager _editorTabManager;
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  late SearchService searchService;
  final Map<int, EditorScrollManager> _scrollManagers = {};

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

  void _toggleFileExplorer() {
    setState(() {
      _isFileExplorerVisible = !_isFileExplorerVisible;
    });
  }

  void openNewTab({int? row, int? col}) {
    final targetRow = row ?? _editorTabManager.activeRow;
    final targetCol = col ?? _editorTabManager.activeCol;
    final scrollManager = _getScrollManager(targetRow, targetCol);

    // Focus the target split view first
    _editorTabManager.focusSplitView(targetRow, targetCol);

    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: () => scrollManager.resetGutterScroll(),
      tapCallback: tapCallback,
    );

    _editorTabManager.addEditor(newEditor, row: targetRow, col: targetCol);

    setState(() {
      _editorTabManager.activeEditor!.openFile('');
      searchService.onSearchTermChanged(
          searchService.searchTerm, _editorTabManager.activeEditor);
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
    // First check if file is already open in any split
    for (int r = 0; r < _editorTabManager.horizontalSplits.length; r++) {
      for (int c = 0; c < _editorTabManager.horizontalSplits[r].length; c++) {
        final editorIndex = _editorTabManager.horizontalSplits[r][c].editors
            .indexWhere((editor) => editor.path == path);
        if (editorIndex != -1) {
          _editorTabManager.focusSplitView(r, c);
          onActiveEditorChanged(editorIndex, row: r, col: c);
          return;
        }
      }
    }

    // If file is not open, create new editor in the currently focused split
    final targetRow = row ?? _editorTabManager.activeRow;
    final targetCol = col ?? _editorTabManager.activeCol;
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
    );

    _editorTabManager.focusSplitView(targetRow, targetCol);

    setState(() {
      _editorTabManager.addEditor(newEditor, row: targetRow, col: targetCol);
      _editorTabManager.activeEditor!.openFile(content);
    });

    searchService.updateSearchMatches(
      searchService.searchTerm,
      _editorTabManager.activeEditor,
    );

    WidgetsBinding.instance.addPostFrameCallback(
        (_) => editorKey.currentState!.updateCachedMaxLineWidth());
  }

  @override
  void initState() {
    super.initState();
    _editorTabManager = EditorTabManager(
      onSplitViewClosed: _cleanupScrollManager,
    );
    _initializationFuture = _initializeServices();
    searchService = SearchService(
      scrollToCursor: () => _scrollToCursor(
        _editorTabManager.activeRow,
        _editorTabManager.activeCol,
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
    for (int r = 0; r < _editorTabManager.horizontalSplits.length; r++) {
      for (int c = 0; c < _editorTabManager.horizontalSplits[r].length; c++) {
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
    if (row >= _editorTabManager.horizontalSplits.length ||
        col >= _editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = _getScrollManager(row, col);
    final activeEditor =
        _editorTabManager.horizontalSplits[row][col].activeEditor;

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
    if (row >= _editorTabManager.horizontalSplits.length ||
        col >= _editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = _getScrollManager(row, col);
    final activeEditor =
        _editorTabManager.horizontalSplits[row][col].activeEditor;

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
    final scrollManager = _getScrollManager(row, col);
    scrollManager.scrollToCursor(
      activeEditor: _editorTabManager.horizontalSplits[row][col].activeEditor,
      layoutService: EditorLayoutService.instance,
    );
  }

  Widget _buildFileExplorer() {
    if (_isFileExplorerVisible) {
      return FileExplorer(
        editorConfigService: _editorConfigService,
        fileService: widget.fileService,
        tapCallback: tapCallback,
        onDirectoryChanged: widget.onDirectoryChanged,
        onDirectoryRefresh: widget.onDirectoryRefresh,
      );
    }

    return const SizedBox.shrink();
  }

  Future<void> _initializeServices() async {
    _editorConfigService = await EditorConfigService.create();
    _isFileExplorerVisible = _editorConfigService.config.isFileExplorerVisible;

    EditorLayoutService(
      horizontalPadding: widget.horizontalPadding,
      verticalPaddingLines: widget.verticalPaddingLines,
      gutterWidth: 40,
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
        if (_editorTabManager.activeSplitView.activeEditorIndex >= 0) {
          onEditorClosed(_editorTabManager.activeSplitView.activeEditorIndex);
        }
      },
      openNewTab: () {
        openNewTab();
      },
      saveFile: () async {
        if (_editorTabManager.activeEditor != null) {
          await _editorTabManager.activeEditor!
              .saveFile(_editorTabManager.activeEditor!.path);
        }
        return Future<void>.value();
      },
      saveFileAs: () async {
        if (_editorTabManager.activeEditor != null) {
          await _editorTabManager.activeEditor!
              .saveFileAs(_editorTabManager.activeEditor!.path);
        }
        return Future<void>.value();
      },
      requestEditorFocus: () {
        if (_editorTabManager.activeEditor != null) {
          _editorTabManager.activeEditor!.requestFocus();
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
        for (int i = 0; i < _editorTabManager.editors.length; i++) {
          if (_editorTabManager.editors[i].path
              .endsWith('editor_config.json')) {
            // Reload the settings file if it is open
            _editorTabManager.editors[i].buffer.setContent(
                FileService.readFile(_editorTabManager.editors[i].path));
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
    final targetRow = row ?? _editorTabManager.activeRow;
    final targetCol = col ?? _editorTabManager.activeCol;

    // Validate indices before proceeding
    if (targetRow >= _editorTabManager.horizontalSplits.length ||
        targetCol >= _editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = _getScrollManager(targetRow, targetCol);
    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));

    setState(() {
      _editorTabManager.setActiveEditor(
        index,
        row: targetRow,
        col: targetCol,
      );

      if (_editorTabManager.activeEditor != null) {
        scrollManager.editorVerticalScrollController
            .jumpTo(_editorTabManager.activeEditor!.scrollState.verticalOffset);
        scrollManager.editorHorizontalScrollController.jumpTo(
            _editorTabManager.activeEditor!.scrollState.horizontalOffset);
        searchService.updateSearchMatches(
          searchService.searchTerm,
          _editorTabManager.activeEditor,
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
    final targetRow = row ?? _editorTabManager.activeRow;
    final targetCol = col ?? _editorTabManager.activeCol;

    // Early validation
    if (targetRow >= _editorTabManager.horizontalSplits.length ||
        targetCol >= _editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = _getScrollManager(targetRow, targetCol);
    final editorKey = _getEditorViewKey(getSplitIndex(targetRow, targetCol));

    setState(() {
      final verticalOffset =
          _editorTabManager.activeEditor?.scrollState.verticalOffset ?? 0.0;
      final horizontalOffset =
          _editorTabManager.activeEditor?.scrollState.horizontalOffset ?? 0.0;

      _editorTabManager.closeEditor(
        index,
        row: targetRow,
        col: targetCol,
      );

      // Only update scroll positions if there's still an active editor
      if (_editorTabManager.activeEditor != null) {
        scrollManager.editorVerticalScrollController.jumpTo(verticalOffset);
        scrollManager.editorHorizontalScrollController.jumpTo(horizontalOffset);
      }
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
      index += _editorTabManager.horizontalSplits[i].length;
    }
    return index + col;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        return ListenableBuilder(
          listenable:
              Listenable.merge([_editorConfigService, _editorTabManager]),
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
                          if (isFileExplorerOnLeft) _buildFileExplorer(),
                          Expanded(
                            child: Column(
                              children: [
                                for (int row = 0;
                                    row <
                                        _editorTabManager
                                            .horizontalSplits.length;
                                    row++)
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (int col = 0;
                                            col <
                                                _editorTabManager
                                                    .horizontalSplits[row]
                                                    .length;
                                            col++)
                                          Expanded(
                                            child: _buildEditorSection(
                                              _editorTabManager
                                                  .horizontalSplits[row][col],
                                              row,
                                              col,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (!isFileExplorerOnLeft) _buildFileExplorer(),
                        ],
                      ),
                    ),
                    StatusBar(
                      editorConfigService: _editorConfigService,
                      onFileExplorerToggle: _toggleFileExplorer,
                      isFileExplorerVisible: _isFileExplorerVisible,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditorSection(SplitView splitView, int row, int col) {
    final scrollManager = _getScrollManager(row, col);
    final editorViewKey = _getEditorViewKey(getSplitIndex(row, col));

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
                if (row < _editorTabManager.horizontalSplits.length &&
                    col < _editorTabManager.horizontalSplits[row].length) {
                  _editorTabManager.focusSplitView(row, col);
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
                _editorTabManager.focusSplitView(row, col);
                if (splitView.activeEditorIndex >= 0) {
                  onActiveEditorChanged(
                    splitView.activeEditorIndex,
                    row: row,
                    col: col,
                  );
                }
              },
              onPointerPanZoomUpdate: (_) {
                _editorTabManager.focusSplitView(row, col);
                if (splitView.activeEditorIndex >= 0) {
                  onActiveEditorChanged(
                    splitView.activeEditorIndex,
                    row: row,
                    col: col,
                  );
                }
              },
              onPointerMove: (event) {
                if (event.kind == PointerDeviceKind.touch || event.down) {
                  _editorTabManager.focusSplitView(row, col);
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
                  border: Border(
                    left: col > 0
                        ? BorderSide(
                            color: _editorConfigService
                                    .themeService.currentTheme?.border ??
                                Colors.grey,
                          )
                        : BorderSide.none,
                    top: row > 0
                        ? BorderSide(
                            color: _editorConfigService
                                    .themeService.currentTheme?.border ??
                                Colors.grey,
                          )
                        : BorderSide.none,
                  ),
                ),
                child: Column(
                  children: [
                    if (splitView.editors.isNotEmpty)
                      Row(
                        children: [
                          Expanded(
                            child: EditorTabBar(
                              onPin: (index) => _editorTabManager.togglePin(
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
                                  _editorTabManager.reorderEditor(
                                oldIndex,
                                newIndex,
                                row: row,
                                col: col,
                              ),
                              onNewTab: () => openNewTab(row: row, col: col),
                              onSplitHorizontal: () =>
                                  _editorTabManager.addHorizontalSplit(),
                              onSplitVertical: () =>
                                  _editorTabManager.addVerticalSplit(),
                              row: row,
                              col: col,
                              onSplitClose: () =>
                                  _editorTabManager.closeSplitView(row, col),
                              editorTabManager: _editorTabManager,
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
                              ),
                            Expanded(
                              child: splitView.editors.isNotEmpty &&
                                      splitView.activeEditor != null
                                  ? EditorView(
                                      key: editorViewKey,
                                      editorConfigService: _editorConfigService,
                                      editorLayoutService:
                                          EditorLayoutService.instance,
                                      state: splitView.activeEditor!,
                                      searchTerm: searchService.searchTerm,
                                      searchTermMatches:
                                          searchService.searchTermMatches,
                                      currentSearchTermMatch:
                                          searchService.currentSearchTermMatch,
                                      onSearchTermChanged: (newTerm) =>
                                          searchService.updateSearchMatches(
                                              newTerm, splitView.activeEditor),
                                      scrollToCursor: () =>
                                          _scrollToCursor(row, col),
                                      onEditorClosed: onEditorClosed,
                                      saveFileAs: () => splitView.activeEditor!
                                          .saveFileAs(
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
      ),
    );
  }
}
