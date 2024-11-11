import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
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
  final editorViewKey = GlobalKey<EditorViewState>();
  late final EditorConfigService _editorConfigService;
  final EditorTabManager _editorTabManager = EditorTabManager();
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  late SearchService searchService;
  late EditorScrollManager editorScrollManager;

  void _toggleFileExplorer() {
    setState(() {
      _isFileExplorerVisible = !_isFileExplorerVisible;
    });
  }

  void openNewTab() {
    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: editorScrollManager.resetGutterScroll,
      tapCallback: tapCallback,
    );

    _editorTabManager.addEditor(newEditor);
    setState(() {
      _editorTabManager.activeEditor!.openFile('');
      searchService.onSearchTermChanged(
          searchService.searchTerm, _editorTabManager.activeEditor);
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorViewKey.currentState != null) {
        editorViewKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  Future<void> tapCallback(String path) async {
    final relativePath = widget.fileService
        .getRelativePath(path, widget.fileService.rootDirectory);

    final editorIndex =
        _editorTabManager.editors.indexWhere((editor) => editor.path == path);
    if (editorIndex != -1) {
      onActiveEditorChanged(editorIndex);
    } else {
      String content = await File(path).readAsString();
      final newEditor = EditorState(
        editorConfigService: _editorConfigService,
        editorLayoutService: EditorLayoutService.instance,
        resetGutterScroll: editorScrollManager.resetGutterScroll,
        path: path,
        relativePath: relativePath,
        tapCallback: tapCallback,
      );
      setState(() {
        _editorTabManager.addEditor(newEditor);
        _editorTabManager.activeEditor!.openFile(content);
      });
    }
    searchService.updateSearchMatches(
        searchService.searchTerm, _editorTabManager.activeEditor);
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
      _editorTabManager.activeEditor?.updateVerticalScrollOffset(
          editorScrollManager.editorVerticalScrollController.offset);
    }
    _editorTabManager.activeEditor?.updateHorizontalScrollOffset(
        editorScrollManager.editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (editorScrollManager.editorVerticalScrollController.offset !=
        editorScrollManager.gutterScrollController.offset) {
      editorScrollManager.editorVerticalScrollController
          .jumpTo(editorScrollManager.gutterScrollController.offset);
      _editorTabManager.activeEditor?.updateVerticalScrollOffset(
          editorScrollManager.gutterScrollController.offset);
    }
  }

  void _scrollToCursor() {
    editorScrollManager.scrollToCursor(
      activeEditor: _editorTabManager.activeEditor,
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
        if (_editorTabManager.activeEditorIndex >= 0) {
          onEditorClosed(_editorTabManager.activeEditorIndex);
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
        // Request focus for the active editor
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
            //r Reload the settings file if it is open
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

  void onActiveEditorChanged(int index) {
    setState(() {
      _editorTabManager.activeEditorIndex = index;
      editorScrollManager.editorVerticalScrollController
          .jumpTo(_editorTabManager.activeEditor!.scrollState.verticalOffset);
      editorScrollManager.editorHorizontalScrollController
          .jumpTo(_editorTabManager.activeEditor!.scrollState.horizontalOffset);
      searchService.updateSearchMatches(
          searchService.searchTerm, _editorTabManager.activeEditor);
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
      if (_editorTabManager.editors.isEmpty ||
          _editorTabManager.editors[index].isPinned) {
        return;
      }

      _editorTabManager.editors.removeAt(index);

      if (_editorTabManager.activeEditorIndex >=
          _editorTabManager.editors.length) {
        _editorTabManager.activeEditorIndex =
            _editorTabManager.editors.length - 1;

        // Reset scroll positions for the new active editor
        if (_editorTabManager.activeEditor != null) {
          editorScrollManager.editorVerticalScrollController.jumpTo(
              _editorTabManager.activeEditor!.scrollState.verticalOffset);
          editorScrollManager.editorHorizontalScrollController.jumpTo(
              _editorTabManager.activeEditor!.scrollState.horizontalOffset);
        }
      }
    });

    // Force a rebuild of the editor view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorViewKey.currentState != null) {
        editorViewKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
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
                    child: ChangeNotifierProvider.value(
                      value: _editorTabManager.activeEditor,
                      child: Consumer<EditorState?>(
                        builder: (context, state, _) {
                          return Material(
                            child: Column(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (isFileExplorerOnLeft)
                                        _buildFileExplorer(),
                                      Expanded(
                                        child: Column(
                                          children: [
                                            if (_editorTabManager
                                                .editors.isNotEmpty)
                                              EditorTabBar(
                                                onPin:
                                                    _editorTabManager.togglePin,
                                                editorConfigService:
                                                    _editorConfigService,
                                                editors:
                                                    _editorTabManager.editors,
                                                activeEditorIndex:
                                                    _editorTabManager
                                                        .activeEditorIndex,
                                                onActiveEditorChanged:
                                                    onActiveEditorChanged,
                                                onEditorClosed: (index) =>
                                                    onEditorClosed(index),
                                                onReorder: _editorTabManager
                                                    .reorderEditor,
                                              ),
                                            if (_editorTabManager
                                                .editors.isNotEmpty)
                                              EditorControlBarView(
                                                editorConfigService:
                                                    _editorConfigService,
                                                filePath: _editorTabManager
                                                        .activeEditor!
                                                        .relativePath ??
                                                    _editorTabManager
                                                        .activeEditor!.path,
                                                searchTermChanged: (newTerm) =>
                                                    searchService
                                                        .onSearchTermChanged(
                                                            newTerm,
                                                            _editorTabManager
                                                                .activeEditor),
                                                nextSearchTerm: () =>
                                                    searchService
                                                        .nextSearchTerm(
                                                            _editorTabManager
                                                                .activeEditor),
                                                previousSearchTerm: () =>
                                                    searchService
                                                        .previousSearchTerm(
                                                            _editorTabManager
                                                                .activeEditor),
                                                currentSearchTermMatch:
                                                    searchService
                                                        .currentSearchTermMatch,
                                                totalSearchTermMatches:
                                                    searchService
                                                        .searchTermMatches
                                                        .length,
                                                isCaseSensitiveActive:
                                                    searchService
                                                        .caseSensitiveActive,
                                                isRegexActive:
                                                    searchService.regexActive,
                                                isWholeWordActive: searchService
                                                    .wholeWordActive,
                                                toggleRegex: (active) =>
                                                    searchService.toggleRegex(
                                                        active,
                                                        _editorTabManager
                                                            .activeEditor),
                                                toggleWholeWord: (active) =>
                                                    searchService
                                                        .toggleWholeWord(
                                                            active,
                                                            _editorTabManager
                                                                .activeEditor),
                                                toggleCaseSensitive: (active) =>
                                                    searchService
                                                        .toggleCaseSensitive(
                                                            active,
                                                            _editorTabManager
                                                                .activeEditor),
                                                replaceNextMatch: (newTerm) =>
                                                    searchService
                                                        .replaceNextMatch(
                                                            newTerm,
                                                            _editorTabManager
                                                                .activeEditor),
                                                replaceAllMatches: (newTerm) =>
                                                    searchService
                                                        .replaceAllMatches(
                                                            newTerm,
                                                            _editorTabManager
                                                                .activeEditor),
                                              ),
                                            Expanded(
                                              child: Container(
                                                color:
                                                    _editorConfigService
                                                                .themeService
                                                                .currentTheme !=
                                                            null
                                                        ? _editorConfigService
                                                            .themeService
                                                            .currentTheme!
                                                            .background
                                                        : Colors.white,
                                                child: Row(
                                                  children: [
                                                    if (_editorTabManager
                                                        .editors.isNotEmpty)
                                                      Gutter(
                                                        editorConfigService:
                                                            _editorConfigService,
                                                        editorLayoutService:
                                                            EditorLayoutService
                                                                .instance,
                                                        editorState: state!,
                                                        verticalScrollController:
                                                            editorScrollManager
                                                                .gutterScrollController,
                                                      ),
                                                    Expanded(
                                                      child: _editorTabManager
                                                              .editors
                                                              .isNotEmpty
                                                          ? EditorView(
                                                              key:
                                                                  editorViewKey,
                                                              editorConfigService:
                                                                  _editorConfigService,
                                                              editorLayoutService:
                                                                  EditorLayoutService
                                                                      .instance,
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
                                                              onSearchTermChanged: (newTerm) =>
                                                                  searchService.updateSearchMatches(
                                                                      newTerm,
                                                                      _editorTabManager
                                                                          .activeEditor),
                                                              scrollToCursor:
                                                                  _scrollToCursor,
                                                              onEditorClosed:
                                                                  onEditorClosed,
                                                              saveFileAs: _editorTabManager
                                                                          .activeEditor !=
                                                                      null
                                                                  ? () => _editorTabManager
                                                                      .activeEditor!
                                                                      .saveFileAs(_editorTabManager
                                                                          .activeEditor!
                                                                          .path)
                                                                  : () => Future<
                                                                      void>.value(),
                                                              saveFile: _editorTabManager
                                                                          .activeEditor !=
                                                                      null
                                                                  ? () => _editorTabManager
                                                                      .activeEditor!
                                                                      .saveFile(_editorTabManager
                                                                          .activeEditor!
                                                                          .path)
                                                                  : () => Future<
                                                                      void>.value(),
                                                              openNewTab:
                                                                  openNewTab,
                                                              activeEditorIndex: () =>
                                                                  _editorTabManager
                                                                      .activeEditorIndex,
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
                                                                  : Colors
                                                                      .white),
                                                    )
                                                  ],
                                                ),
                                              ),
                                            )
                                          ],
                                        ),
                                      ),
                                      if (!isFileExplorerOnLeft)
                                        _buildFileExplorer(),
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
        });
  }
}
