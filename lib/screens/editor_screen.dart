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
  final EditorTabManager _editorTabManager = EditorTabManager();
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  late SearchService searchService;
  final Map<int, EditorScrollManager> _scrollManagers = {};

  EditorScrollManager _getScrollManager(int splitViewIndex) {
    if (!_scrollManagers.containsKey(splitViewIndex)) {
      final scrollManager = EditorScrollManager();
      scrollManager.initListeners(
        onEditorScroll: () => _handleEditorScroll(splitViewIndex),
        onGutterScroll: () => _handleGutterScroll(splitViewIndex),
      );
      _scrollManagers[splitViewIndex] = scrollManager;
    }
    return _scrollManagers[splitViewIndex]!;
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

  void openNewTab([int? splitViewIndex]) {
    final targetSplitIndex =
        splitViewIndex ?? _editorTabManager.activeSplitViewIndex;

    // Focus the target split view first
    _editorTabManager.focusSplitView(targetSplitIndex);

    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: () =>
          _getScrollManager(targetSplitIndex).resetGutterScroll(),
      tapCallback: tapCallback,
    );

    _editorTabManager.addEditor(newEditor, splitViewIndex: targetSplitIndex);

    setState(() {
      _editorTabManager.activeEditor!.openFile('');
      searchService.onSearchTermChanged(
          searchService.searchTerm, _editorTabManager.activeEditor);
    });

    final editorKey = _getEditorViewKey(targetSplitIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null) {
        editorKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  Future<void> tapCallback(String path, [int? splitViewIndex]) async {
    // First check if file is already open in any split
    for (int i = 0; i < _editorTabManager.splitViews.length; i++) {
      final editorIndex = _editorTabManager.splitViews[i].editors
          .indexWhere((editor) => editor.path == path);
      if (editorIndex != -1) {
        _editorTabManager.focusSplitView(i);
        onActiveEditorChanged(editorIndex, i);
        return;
      }
    }

    // If file is not open, create new editor in the currently focused split
    final targetSplitIndex =
        splitViewIndex ?? _editorTabManager.activeSplitViewIndex;
    final scrollManager = _getScrollManager(targetSplitIndex);
    final editorKey = _getEditorViewKey(targetSplitIndex);

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

    _editorTabManager.focusSplitView(targetSplitIndex);

    setState(() {
      _editorTabManager.addEditor(newEditor, splitViewIndex: targetSplitIndex);
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
    _initializationFuture = _initializeServices();
    searchService = SearchService(
        scrollToCursor: () =>
            _scrollToCursor(_editorTabManager.activeSplitViewIndex));

    // Initialize scroll manager for the first split view
    _getScrollManager(0);
  }

  void _handleEditorScroll(int splitViewIndex) {
    final scrollManager = _getScrollManager(splitViewIndex);
    if (scrollManager.gutterScrollController.offset !=
        scrollManager.editorVerticalScrollController.offset) {
      scrollManager.gutterScrollController
          .jumpTo(scrollManager.editorVerticalScrollController.offset);
      _editorTabManager.splitViews[splitViewIndex].activeEditor
          ?.updateVerticalScrollOffset(
              scrollManager.editorVerticalScrollController.offset);
    }
    _editorTabManager.splitViews[splitViewIndex].activeEditor
        ?.updateHorizontalScrollOffset(
            scrollManager.editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll(int splitViewIndex) {
    final scrollManager = _getScrollManager(splitViewIndex);
    if (scrollManager.editorVerticalScrollController.offset !=
        scrollManager.gutterScrollController.offset) {
      scrollManager.editorVerticalScrollController
          .jumpTo(scrollManager.gutterScrollController.offset);
      _editorTabManager.splitViews[splitViewIndex].activeEditor
          ?.updateVerticalScrollOffset(
              scrollManager.gutterScrollController.offset);
    }
  }

  void _scrollToCursor(int splitViewIndex) {
    final scrollManager = _getScrollManager(splitViewIndex);
    scrollManager.scrollToCursor(
      activeEditor: _editorTabManager.splitViews[splitViewIndex].activeEditor,
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

  void onActiveEditorChanged(int index, [int? splitViewIndex]) {
    final targetSplitIndex =
        splitViewIndex ?? _editorTabManager.activeSplitViewIndex;
    final scrollManager = _getScrollManager(targetSplitIndex);
    final editorKey = _getEditorViewKey(targetSplitIndex);

    setState(() {
      _editorTabManager.setActiveEditor(index, splitViewIndex: splitViewIndex);

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

  void onEditorClosed(int index, [int? splitViewIndex]) {
    final targetSplitIndex =
        splitViewIndex ?? _editorTabManager.activeSplitViewIndex;
    final scrollManager = _getScrollManager(targetSplitIndex);
    final editorKey = _getEditorViewKey(targetSplitIndex);

    setState(() {
      _editorTabManager.closeEditor(index, splitViewIndex: splitViewIndex);

      if (_editorTabManager.activeEditor != null) {
        scrollManager.editorVerticalScrollController.jumpTo(
          _editorTabManager.activeEditor!.scrollState.verticalOffset,
        );
        scrollManager.editorHorizontalScrollController.jumpTo(
          _editorTabManager.activeEditor!.scrollState.horizontalOffset,
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
                            child: Row(
                              children: [
                                for (int i = 0;
                                    i < _editorTabManager.splitViews.length;
                                    i++)
                                  Expanded(
                                    child: ChangeNotifierProvider.value(
                                      value: _editorTabManager
                                          .splitViews[i].activeEditor,
                                      child: Builder(
                                        builder: (context) =>
                                            _buildEditorSection(
                                          _editorTabManager.splitViews[i],
                                          i,
                                        ),
                                      ),
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

  Widget _buildEditorSection(SplitView splitView, int splitViewIndex) {
    final scrollManager = _getScrollManager(splitViewIndex);
    final editorViewKey = _getEditorViewKey(splitViewIndex);

    return Consumer<EditorState?>(
      builder: (context, state, _) {
        return MouseRegion(
            cursor: SystemMouseCursors.text,
            child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  _editorTabManager.focusSplitView(splitViewIndex);
                },
                child: Container(
                    decoration: BoxDecoration(
                      color: _editorConfigService
                              .themeService.currentTheme?.background ??
                          Colors.white,
                      border: Border(
                        left: splitViewIndex > 0
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
                                      splitViewIndex: splitViewIndex),
                                  editorConfigService: _editorConfigService,
                                  editors: splitView.editors,
                                  activeEditorIndex:
                                      splitView.activeEditorIndex,
                                  onActiveEditorChanged: (index) =>
                                      onActiveEditorChanged(
                                          index, splitViewIndex),
                                  onEditorClosed: (index) =>
                                      onEditorClosed(index, splitViewIndex),
                                  onReorder: (oldIndex, newIndex) =>
                                      _editorTabManager.reorderEditor(
                                          oldIndex, newIndex,
                                          splitViewIndex: splitViewIndex),
                                  onNewTab: () => openNewTab(splitViewIndex),
                                  onSplitHorizontal: () => _editorTabManager
                                      .addSplitView(vertical: false),
                                  onSplitVertical: () =>
                                      _editorTabManager.addSplitView(),
                                  splitViewIndex: splitViewIndex,
                                  onSplitClose: (index) =>
                                      _editorTabManager.closeSplitView(index),
                                  editorTabManager: _editorTabManager,
                                ),
                              ),
                            ],
                          ),
                        if (splitView.editors.isNotEmpty)
                          EditorControlBarView(
                            editorConfigService: _editorConfigService,
                            filePath: state?.relativePath ?? state?.path ?? '',
                            searchTermChanged: (newTerm) => searchService
                                .onSearchTermChanged(newTerm, state),
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
                            toggleCaseSensitive: (active) => searchService
                                .toggleCaseSensitive(active, state),
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
                                if (splitView.editors.isNotEmpty &&
                                    state != null)
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
                                          state != null
                                      ? EditorView(
                                          key: editorViewKey,
                                          editorConfigService:
                                              _editorConfigService,
                                          editorLayoutService:
                                              EditorLayoutService.instance,
                                          state: state,
                                          searchTerm: searchService.searchTerm,
                                          searchTermMatches:
                                              searchService.searchTermMatches,
                                          currentSearchTermMatch: searchService
                                              .currentSearchTermMatch,
                                          onSearchTermChanged: (newTerm) =>
                                              searchService.updateSearchMatches(
                                                  newTerm, state),
                                          scrollToCursor: () =>
                                              _scrollToCursor(splitViewIndex),
                                          onEditorClosed: onEditorClosed,
                                          saveFileAs: () =>
                                              state.saveFileAs(state.path),
                                          saveFile: () =>
                                              state.saveFile(state.path),
                                          openNewTab: openNewTab,
                                          activeEditorIndex: () =>
                                              splitView.activeEditorIndex,
                                          verticalScrollController: scrollManager
                                              .editorVerticalScrollController,
                                          horizontalScrollController: scrollManager
                                              .editorHorizontalScrollController,
                                          focusSplitView: () =>
                                              _editorTabManager.focusSplitView(
                                                  splitViewIndex),
                                        )
                                      : Container(
                                          color: _editorConfigService
                                                  .themeService
                                                  .currentTheme
                                                  ?.background ??
                                              Colors.white,
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ))));
      },
    );
  }
}
