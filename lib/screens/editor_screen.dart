import 'dart:io';
import 'dart:math';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
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
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _editorVerticalScrollController = ScrollController();
  final ScrollController _editorHorizontalScrollController = ScrollController();
  final List<EditorState> _editors = [];
  late SearchService searchService;

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
      resetGutterScroll: _resetGutterScroll,
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
        resetGutterScroll: _resetGutterScroll,
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
  }

  @override
  void initState() {
    super.initState();
    _initializationFuture = _initializeServices();
    searchService = SearchService(scrollToCursor: _scrollToCursor);
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

    // Listeners
    _editorVerticalScrollController.addListener(_handleEditorScroll);
    _editorHorizontalScrollController.addListener(_handleEditorScroll);
    _gutterScrollController.addListener(_handleGutterScroll);
    _editorConfigService.themeService.addListener(_onThemeChanged);
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEditorScroll() {
    if (_gutterScrollController.offset !=
        _editorVerticalScrollController.offset) {
      _gutterScrollController.jumpTo(_editorVerticalScrollController.offset);
      activeEditor!
          .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    }

    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (_editorVerticalScrollController.offset !=
        _gutterScrollController.offset) {
      _editorVerticalScrollController.jumpTo(_gutterScrollController.offset);
      activeEditor!.updateVerticalScrollOffset(_gutterScrollController.offset);
    }
  }

  void _scrollToCursor() {
    if (activeEditor == null) return;

    final cursor = activeEditor!.editorCursorManager.cursors.last;
    final cursorLine = cursor.line;
    final lineHeight = _editorLayoutService.config.lineHeight;
    final viewportHeight =
        _editorVerticalScrollController.position.viewportDimension;
    final currentOffset = _editorVerticalScrollController.offset;
    final verticalPadding = _editorLayoutService.config.verticalPadding;

    // Vertical scrolling
    final cursorY = cursorLine * lineHeight;
    if (cursorY < currentOffset + verticalPadding) {
      _editorVerticalScrollController.jumpTo(max(0, cursorY - verticalPadding));
    } else if (cursorY + lineHeight >
        currentOffset + viewportHeight - verticalPadding) {
      _editorVerticalScrollController
          .jumpTo(cursorY + lineHeight - viewportHeight + verticalPadding);
    }

    // Horizontal scrolling
    final cursorColumn = cursor.column;
    final currentLine = activeEditor!.buffer.getLine(cursorLine);

    final safeColumn = min(cursorColumn, currentLine.length);
    final textBeforeCursor = currentLine.substring(0, safeColumn);

    final cursorX =
        textBeforeCursor.length * _editorLayoutService.config.charWidth;
    final viewportWidth =
        _editorHorizontalScrollController.position.viewportDimension;
    final currentHorizontalOffset = _editorHorizontalScrollController.offset;
    final horizontalPadding = _editorLayoutService.config.horizontalPadding;

    if (cursorX < currentHorizontalOffset + horizontalPadding) {
      _editorHorizontalScrollController
          .jumpTo(max(0, cursorX - horizontalPadding));
    } else if (cursorX + _editorLayoutService.config.charWidth >
        currentHorizontalOffset + viewportWidth - horizontalPadding) {
      _editorHorizontalScrollController.jumpTo(cursorX +
          _editorLayoutService.config.charWidth -
          viewportWidth +
          horizontalPadding);
    }

    // Update editor offsets
    activeEditor!
        .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _resetGutterScroll() {
    if (_gutterScrollController.hasClients) _gutterScrollController.jumpTo(0);
  }

  void onActiveEditorChanged(int index) {
    setState(() {
      activeEditorIndex = index;
      _editorVerticalScrollController
          .jumpTo(activeEditor!.scrollState.verticalOffset);
      _editorHorizontalScrollController
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
    _gutterScrollController.removeListener(_handleEditorScroll);
    _gutterScrollController.removeListener(_handleGutterScroll);
    _gutterScrollController.dispose();
    _editorVerticalScrollController.dispose();
    _editorHorizontalScrollController.dispose();
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
                                                      _gutterScrollController,
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
                                                            _editorVerticalScrollController,
                                                        horizontalScrollController:
                                                            _editorHorizontalScrollController,
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
