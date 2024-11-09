import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_scroll_manager.dart';
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
  final String? currentDirectory;
  final Function(String)? onDirectoryChanged;
  final Function()? onDirectoryRefresh;

  const EditorScreen({
    super.key,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultipler,
    required this.currentDirectory,
    required this.onDirectoryChanged,
    required this.onDirectoryRefresh,
  });

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  bool _isFileExplorerVisible = true;
  final editorViewKey = GlobalKey<EditorViewState>();
  late final EditorLayoutService _editorLayoutService;
  late final EditorConfigService _editorConfigService;
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  final List<EditorState> _editors = [];
  late SearchService searchService;
  late EditorScrollManager editorScrollManager;

  int activeEditorIndex = 0;
  EditorState? get activeEditor =>
      _editors.isEmpty ? null : _editors[activeEditorIndex];

  void _toggleFileExplorer() {
    setState(() {
      _isFileExplorerVisible = !_isFileExplorerVisible;
    });
  }

  void openNewTab() {
    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: _editorLayoutService,
      resetGutterScroll: editorScrollManager.resetGutterScroll,
      tapCallback: tapCallback,
    );

    setState(() {
      _editors.add(newEditor);
      activeEditorIndex = _editors.length - 1;
      _editors[activeEditorIndex].openFile('');
      searchService.onSearchTermChanged(searchService.searchTerm, activeEditor);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorViewKey.currentState != null) {
        editorViewKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  String getRelativePath(String fullPath, String rootDir) {
    if (!fullPath.startsWith(rootDir)) {
      return fullPath;
    }

    String relativePath = fullPath.substring(rootDir.length);
    if (relativePath.startsWith(Platform.pathSeparator)) {
      relativePath = relativePath.substring(1);
    }

    return relativePath;
  }

  Future<void> tapCallback(String path) async {
    final relativePath = getRelativePath(path, widget.currentDirectory ?? '');

    final editorIndex = _editors.indexWhere((editor) => editor.path == path);
    if (editorIndex != -1) {
      setState(() {
        activeEditorIndex = editorIndex;
      });
    } else {
      String content = await File(path).readAsString();
      final newEditor = EditorState(
        editorConfigService: _editorConfigService,
        editorLayoutService: _editorLayoutService,
        resetGutterScroll: editorScrollManager.resetGutterScroll,
        path: path,
        relativePath: relativePath,
        tapCallback: tapCallback,
      );
      setState(() {
        _editors.add(newEditor);
        activeEditorIndex = _editors.length - 1;
        _editors[activeEditorIndex].openFile(content);
      });
    }
    searchService.onSearchTermChanged(searchService.searchTerm, activeEditor);
  }

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeServices();
    searchService = SearchService(scrollToCursor: _scrollToCursor);
    editorScrollManager = EditorScrollManager();

    // Scroll Listeners
    editorScrollManager.initListeners(
      onEditorScroll: _handleEditorScroll,
      onGutterScroll: _handleGutterScroll,
    );
  }

  void _handleEditorScroll() {
    if (editorScrollManager.gutterScrollController.offset !=
        editorScrollManager.editorVerticalScrollController.offset) {
      editorScrollManager.gutterScrollController
          .jumpTo(editorScrollManager.editorVerticalScrollController.offset);
      activeEditor?.updateVerticalScrollOffset(
          editorScrollManager.editorVerticalScrollController.offset);
    }
    activeEditor?.updateHorizontalScrollOffset(
        editorScrollManager.editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (editorScrollManager.editorVerticalScrollController.offset !=
        editorScrollManager.gutterScrollController.offset) {
      editorScrollManager.editorVerticalScrollController
          .jumpTo(editorScrollManager.gutterScrollController.offset);
      activeEditor?.updateVerticalScrollOffset(
          editorScrollManager.gutterScrollController.offset);
    }
  }

  void _scrollToCursor() {
    editorScrollManager.scrollToCursor(
      activeEditor: activeEditor,
      layoutService: _editorLayoutService,
    );
  }

  Future<void> _initializeServices() async {
    _editorConfigService = await EditorConfigService.create();
    _isFileExplorerVisible = _editorConfigService.config.isFileExplorerVisible;

    _editorLayoutService = EditorLayoutService(
      fontFamily: _editorConfigService.config.fontFamily,
      fontSize: _editorConfigService.config.fontSize,
      horizontalPadding: widget.horizontalPadding,
      verticalPaddingLines: widget.verticalPaddingLines,
      lineHeightMultiplier: widget.lineHeightMultipler,
    );

    _shortcutHandler = ShortcutHandler(
      openSettings: _openSettings,
      openDefaultSettings: _openDefaultSettings,
      closeTab: () {
        if (activeEditorIndex >= 0) {
          onEditorClosed(activeEditorIndex);
        }
      },
      openNewTab: () {
        openNewTab();
      },
      saveFile: () async {
        if (activeEditor != null) {
          await activeEditor!.saveFile(activeEditor!.path);
        }
        return Future<void>.value();
      },
      saveFileAs: () async {
        if (activeEditor != null) {
          await activeEditor!.saveFileAs(activeEditor!.path);
        }
        return Future<void>.value();
      },
      requestEditorFocus: () {
        // Request focus for the active editor
        if (activeEditor != null) {
          activeEditor!.requestFocus();
        }
      },
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void onActiveEditorChanged(int index) {
    setState(() {
      activeEditorIndex = index;
      editorScrollManager.editorVerticalScrollController
          .jumpTo(activeEditor!.scrollState.verticalOffset);
      editorScrollManager.editorHorizontalScrollController
          .jumpTo(activeEditor!.scrollState.horizontalOffset);
      searchService.onSearchTermChanged(searchService.searchTerm, activeEditor);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorViewKey.currentState != null) {
        editorViewKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  void onEditorClosed(int index) {
    setState(() {
      if (_editors.isEmpty || _editors[index].isPinned) {
        return;
      }

      _editors.removeAt(index);

      if (activeEditorIndex >= _editors.length) {
        activeEditorIndex = _editors.length - 1;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorViewKey.currentState != null) {
        editorViewKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  void onPin(int index) {
    setState(() {
      _editors[index].isPinned = !_editors[index].isPinned;

      if (_editors[index].isPinned) {
        int pinnedCount = _editors.where((e) => e.isPinned).length - 1;
        if (index > pinnedCount) {
          final editor = _editors.removeAt(index);
          _editors.insert(pinnedCount, editor);
          if (activeEditorIndex == index) {
            activeEditorIndex = pinnedCount;
          }
        }
      }
    });
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      final movingEditor = _editors[oldIndex];
      final pinnedCount = _editors.where((e) => e.isPinned).length;

      // Prevent moving unpinned tabs before pinned ones
      if (!movingEditor.isPinned && newIndex < pinnedCount) {
        newIndex = pinnedCount;
      }

      // Prevent moving pinned tabs after unpinned ones
      if (movingEditor.isPinned && newIndex > pinnedCount - 1) {
        newIndex = pinnedCount - 1;
      }

      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final item = _editors.removeAt(oldIndex);
      _editors.insert(newIndex, item);

      // Update activeEditorIndex
      if (activeEditorIndex == oldIndex) {
        activeEditorIndex = newIndex;
      } else if (activeEditorIndex > oldIndex &&
          activeEditorIndex <= newIndex) {
        activeEditorIndex--;
      } else if (activeEditorIndex < oldIndex &&
          activeEditorIndex >= newIndex) {
        activeEditorIndex++;
      }
    });
  }

  @override
  void dispose() {
    editorScrollManager.removeListeners(
      onEditorScroll: _handleEditorScroll,
      onGutterScroll: _handleGutterScroll,
    );
    editorScrollManager.dispose();
    _editorConfigService.themeService.removeListener(_onThemeChanged);
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

          return Focus(
              autofocus: true,
              onKeyEvent: (node, event) =>
                  _shortcutHandler.handleKeyEvent(node, event),
              child: ChangeNotifierProvider.value(
                value: activeEditor,
                child: Consumer<EditorState?>(
                  builder: (context, state, _) {
                    final gutterWidth = state?.getGutterWidth();

                    return Material(
                      child: Column(
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                if (_isFileExplorerVisible)
                                  FileExplorer(
                                    editorConfigService: _editorConfigService,
                                    rootDir: widget.currentDirectory ?? '',
                                    tapCallback: tapCallback,
                                    onDirectoryChanged:
                                        widget.onDirectoryChanged,
                                    onDirectoryRefresh:
                                        widget.onDirectoryRefresh,
                                  ),
                                Expanded(
                                  child: Column(
                                    children: [
                                      if (_editors.isNotEmpty)
                                        EditorTabBar(
                                          onPin: onPin,
                                          editorConfigService:
                                              _editorConfigService,
                                          editors: _editors,
                                          activeEditorIndex: activeEditorIndex,
                                          onActiveEditorChanged:
                                              onActiveEditorChanged,
                                          onEditorClosed: (index) =>
                                              onEditorClosed(index),
                                          onReorder: onReorder,
                                        ),
                                      if (_editors.isNotEmpty)
                                        EditorControlBarView(
                                          editorConfigService:
                                              _editorConfigService,
                                          filePath:
                                              activeEditor!.relativePath ??
                                                  activeEditor!.path,
                                          searchTermChanged: (newTerm) =>
                                              searchService.onSearchTermChanged(
                                                  newTerm, activeEditor),
                                          nextSearchTerm: () => searchService
                                              .nextSearchTerm(activeEditor),
                                          previousSearchTerm: () =>
                                              searchService.previousSearchTerm(
                                                  activeEditor),
                                          currentSearchTermMatch: searchService
                                              .currentSearchTermMatch,
                                          totalSearchTermMatches: searchService
                                              .searchTermMatches.length,
                                          isCaseSensitiveActive:
                                              searchService.caseSensitiveActive,
                                          isRegexActive:
                                              searchService.regexActive,
                                          isWholeWordActive:
                                              searchService.wholeWordActive,
                                          toggleRegex: (active) =>
                                              searchService.toggleRegex(
                                                  active, activeEditor),
                                          toggleWholeWord: (active) =>
                                              searchService.toggleWholeWord(
                                                  active, activeEditor),
                                          toggleCaseSensitive: (active) =>
                                              searchService.toggleCaseSensitive(
                                                  active, activeEditor),
                                          replaceNextMatch: (newTerm) =>
                                              searchService.replaceNextMatch(
                                                  newTerm, activeEditor),
                                          replaceAllMatches: (newTerm) =>
                                              searchService.replaceAllMatches(
                                                  newTerm, activeEditor),
                                        ),
                                      Expanded(
                                        child: Container(
                                          color:
                                              _editorConfigService.themeService
                                                          .currentTheme !=
                                                      null
                                                  ? _editorConfigService
                                                      .themeService
                                                      .currentTheme!
                                                      .background
                                                  : Colors.white,
                                          child: Row(
                                            children: [
                                              if (_editors.isNotEmpty)
                                                Gutter(
                                                  editorConfigService:
                                                      _editorConfigService,
                                                  editorLayoutService:
                                                      _editorLayoutService,
                                                  editorState: state!,
                                                  verticalScrollController:
                                                      editorScrollManager
                                                          .gutterScrollController,
                                                ),
                                              Expanded(
                                                child: _editors.isNotEmpty
                                                    ? EditorView(
                                                        key: editorViewKey,
                                                        editorConfigService:
                                                            _editorConfigService,
                                                        editorLayoutService:
                                                            _editorLayoutService,
                                                        state: state!,
                                                        searchTerm:
                                                            searchService
                                                                .searchTerm,
                                                        searchTermMatches:
                                                            searchService
                                                                .searchTermMatches,
                                                        currentSearchTermMatch:
                                                            searchService
                                                                .currentSearchTermMatch,
                                                        onSearchTermChanged:
                                                            (newTerm) => searchService
                                                                .updateSearchMatches(
                                                                    newTerm,
                                                                    activeEditor),
                                                        scrollToCursor:
                                                            _scrollToCursor,
                                                        onEditorClosed:
                                                            onEditorClosed,
                                                        saveFileAs: activeEditor !=
                                                                null
                                                            ? () => activeEditor!
                                                                .saveFileAs(
                                                                    activeEditor!
                                                                        .path)
                                                            : () => Future<
                                                                void>.value(),
                                                        saveFile: activeEditor !=
                                                                null
                                                            ? () => activeEditor!
                                                                .saveFile(
                                                                    activeEditor!
                                                                        .path)
                                                            : () => Future<
                                                                void>.value(),
                                                        openNewTab: openNewTab,
                                                        activeEditorIndex: () =>
                                                            activeEditorIndex,
                                                        gutterWidth:
                                                            gutterWidth!,
                                                        verticalScrollController:
                                                            editorScrollManager
                                                                .editorVerticalScrollController,
                                                        horizontalScrollController:
                                                            editorScrollManager
                                                                .editorHorizontalScrollController,
                                                      )
                                                    : Container(
                                                        color: _editorConfigService
                                                                    .themeService
                                                                    .currentTheme !=
                                                                null
                                                            ? _editorConfigService
                                                                .themeService
                                                                .currentTheme!
                                                                .background
                                                            : Colors.white),
                                              )
                                            ],
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
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
                    );
                  },
                ),
              ));
        });
  }
}
