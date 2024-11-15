import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/notifcation_type.dart';
import 'package:crystal/models/notification_action.dart';
import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/screens/editor/editor_section.dart';
import 'package:crystal/screens/editor/file_explorer/file_explorer_container.dart';
import 'package:crystal/screens/editor/terminal/terminal_section.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_scroll_manager.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/notification_service.dart';
import 'package:crystal/services/search_service.dart';
import 'package:crystal/services/shortcut_handler.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/resizable_split_container.dart';
import 'package:crystal/widgets/status_bar/status_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorScreen extends StatefulWidget {
  final double horizontalPadding;
  final int verticalPaddingLines;
  final double lineHeightMultipler;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final NotificationService notificationService;

  const EditorScreen({
    super.key,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultipler,
    required this.onDirectoryChanged,
    required this.fileService,
    required this.notificationService,
  });

  @override
  State<StatefulWidget> createState() => EditorScreenState();
}

class EditorScreenState extends State<EditorScreen> {
  late final EditorConfigService _editorConfigService;
  late final ShortcutHandler _shortcutHandler;
  late final Future<void> _initializationFuture;
  late SearchService searchService;
  final Map<int, EditorScrollManager> _scrollManagers = {};

  EditorTabManager get editorTabManager =>
      context.read<EditorStateProvider>().editorTabManager;

  void scrollToTab(int index) {
    final editorState = context.read<EditorStateProvider>();
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = editorTabManager.activeRow;
      final col = editorTabManager.activeCol;
      final splitView =
          editorTabManager.horizontalSplits[editorTabManager.activeRow]
              [editorTabManager.activeCol];

      if (index < 0 || index >= splitView.editors.length) return;

      final tabBarKey = editorState.getTabBarKey(
          editorTabManager.activeRow, editorTabManager.activeCol);
      final tabBarContext = tabBarKey.currentContext;
      if (tabBarContext == null) return;

      final scrollController = editorState.getTabBarScrollController(row, col);
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

  void openNewTab({int? row, int? col}) {
    final editorState = context.read<EditorStateProvider>();
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;
    final scrollManager = editorState.getScrollManager(targetRow, targetCol);

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

    final editorKey = editorState.getEditorViewKey(targetRow, targetCol);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null) {
        editorKey.currentState!.updateCachedMaxLineWidth();
        setState(() {});
      }
    });
  }

  Future<void> tapCallback(String path, {int? row, int? col}) async {
    final editorState = context.read<EditorStateProvider>();
    final notificationService = widget.notificationService;
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Check if file is already open in the current split
    final editorIndex = editorTabManager
        .horizontalSplits[targetRow][targetCol].editors
        .indexWhere((editor) => editor.path == path);

    if (editorIndex != -1) {
      editorTabManager.focusSplitView(targetRow, targetCol);
      onActiveEditorChanged(editorIndex, row: targetRow, col: targetCol);
      scrollToTab(editorIndex);
      return;
    }

    try {
      final scrollManager = editorState.getScrollManager(targetRow, targetCol);
      final editorKey = editorState.getEditorViewKey(targetRow, targetCol);

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

      final newEditorIndex = editorTabManager
              .horizontalSplits[targetRow][targetCol].editors.length -
          1;
      scrollToTab(newEditorIndex);

      WidgetsBinding.instance.addPostFrameCallback(
          (_) => editorKey.currentState!.updateCachedMaxLineWidth());
    } catch (e) {
      notificationService.show(
        'Failed to open file: ${e.toString()}',
        type: NotificationType.error,
        duration: const Duration(seconds: 5),
        action: NotificationAction(
          label: 'Retry',
          onPressed: () => tapCallback(path, row: row, col: col),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    final editorState = context.read<EditorStateProvider>();
    _initializationFuture = _initializeServices();
    searchService = SearchService(
      scrollToCursor: () => _scrollToCursor(
        editorTabManager.activeRow,
        editorTabManager.activeCol,
      ),
    );

    editorState.getScrollManager(0, 0);
  }

  void _scrollToCursor(int row, int col) {
    final editorState = context.read<EditorStateProvider>();
    // Validate indices before proceeding
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = editorState.getScrollManager(row, col);
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
      isDirty: () => editorTabManager.activeEditor!.buffer.isDirty,
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
    final editorState = context.read<EditorStateProvider>();
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Validate indices before proceeding
    if (targetRow >= editorTabManager.horizontalSplits.length ||
        targetCol >= editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = editorState.getScrollManager(targetRow, targetCol);
    final editorKey = editorState.getEditorViewKey(targetRow, targetCol);

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
    final editorState = context.read<EditorStateProvider>();
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Early validation
    if (targetRow >= editorTabManager.horizontalSplits.length ||
        targetCol >= editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    final scrollManager = editorState.getScrollManager(targetRow, targetCol);
    final editorKey = editorState.getEditorViewKey(targetRow, targetCol);

    setState(() {
      editorTabManager.closeEditor(
        index,
        row: targetRow,
        col: targetCol,
      );
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (editorKey.currentState != null && mounted) {
        final verticalOffset =
            editorTabManager.activeEditor?.scrollState.verticalOffset ?? 0.0;
        final horizontalOffset =
            editorTabManager.activeEditor?.scrollState.horizontalOffset ?? 0.0;

        editorKey.currentState!.updateCachedMaxLineWidth();
        if (mounted) {
          setState(() {
            scrollManager.editorVerticalScrollController.jumpTo(verticalOffset);
            scrollManager.editorHorizontalScrollController
                .jumpTo(horizontalOffset);
          });
        }
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
            child: ListenableBuilder(
              listenable:
                  Listenable.merge([_editorConfigService, editorTabManager]),
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
                                    editorConfigService: _editorConfigService,
                                    fileService: widget.fileService,
                                    tapCallback: tapCallback,
                                    onDirectoryChanged:
                                        widget.onDirectoryChanged),
                              Expanded(
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: editorTabManager
                                              .horizontalSplits.isEmpty
                                          ? Container()
                                          : ResizableSplitContainer(
                                              direction: Axis.vertical,
                                              initialSizes: List.generate(
                                                editorTabManager
                                                    .horizontalSplits.length,
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
                                                    .horizontalSplits.length,
                                                (row) {
                                                  return editorTabManager
                                                          .horizontalSplits[row]
                                                          .isEmpty
                                                      ? Container()
                                                      : ResizableSplitContainer(
                                                          direction:
                                                              Axis.horizontal,
                                                          initialSizes:
                                                              List.generate(
                                                            editorTabManager
                                                                .horizontalSplits[
                                                                    row]
                                                                .length,
                                                            (index) =>
                                                                1.0 /
                                                                editorTabManager
                                                                    .horizontalSplits[
                                                                        row]
                                                                    .length,
                                                          ),
                                                          onSizesChanged: (sizes) =>
                                                              editorTabManager
                                                                  .updateHorizontalSizes(
                                                                      row,
                                                                      sizes),
                                                          editorConfigService:
                                                              _editorConfigService,
                                                          children:
                                                              List.generate(
                                                                  editorTabManager
                                                                      .horizontalSplits[
                                                                          row]
                                                                      .length,
                                                                  (col) =>
                                                                      EditorSection(
                                                                        splitView:
                                                                            editorTabManager.horizontalSplits[row][col],
                                                                        row:
                                                                            row,
                                                                        col:
                                                                            col,
                                                                        editorConfigService:
                                                                            _editorConfigService,
                                                                        editorTabManager:
                                                                            editorTabManager,
                                                                        searchService:
                                                                            searchService,
                                                                        onActiveEditorChanged:
                                                                            onActiveEditorChanged,
                                                                        onEditorClosed:
                                                                            onEditorClosed,
                                                                        openNewTab:
                                                                            openNewTab,
                                                                        scrollToCursor:
                                                                            _scrollToCursor,
                                                                        onDirectoryChanged:
                                                                            widget.onDirectoryChanged,
                                                                        fileService:
                                                                            widget.fileService,
                                                                        selectedSuggestionIndex: editorTabManager.activeEditor ==
                                                                                null
                                                                            ? 0
                                                                            : editorTabManager.activeEditor!.selectedSuggestionIndex,
                                                                      )),
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
                                    editorConfigService: _editorConfigService,
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
    );
  }
}
