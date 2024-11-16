import 'dart:io';

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/notifcation_type.dart';
import 'package:crystal/models/notification_action.dart';
import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/screens/editor/editor_section.dart';
import 'package:crystal/screens/editor/file_explorer/file_explorer_container.dart';
import 'package:crystal/screens/editor/terminal/terminal_section.dart';
import 'package:crystal/services/command_palette_service.dart';
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
      editors: editorTabManager
          .horizontalSplits[editorTabManager.activeRow]
              [editorTabManager.activeCol]
          .editors,
      editorTabManager: editorTabManager,
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

  void openFile(String filePath, {int? row, int? col}) {
    final editorState = context.read<EditorStateProvider>();
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Check if there's already a tab open with this file
    final existingEditor = editorTabManager.findEditorWithFile(filePath);

    if (existingEditor != null) {
      // If the file is already open, just focus that tab
      int editorIndex = editorTabManager
          .horizontalSplits[editorTabManager.activeRow]
              [editorTabManager.activeCol]
          .editors
          .indexOf(existingEditor);

      editorTabManager.setActiveEditor(editorIndex);
      return;
    }

    // If we need a new tab, create one
    final scrollManager = editorState.getScrollManager(targetRow, targetCol);
    editorTabManager.focusSplitView(targetRow, targetCol);

    final newEditor = EditorState(
      editorConfigService: _editorConfigService,
      editorLayoutService: EditorLayoutService.instance,
      resetGutterScroll: () => scrollManager.resetGutterScroll(),
      tapCallback: tapCallback,
      onDirectoryChanged: widget.onDirectoryChanged,
      fileService: widget.fileService,
      editors: editorTabManager
          .horizontalSplits[editorTabManager.activeRow]
              [editorTabManager.activeCol]
          .editors,
      editorTabManager: editorTabManager,
    );

    editorTabManager.addEditor(newEditor, row: targetRow, col: targetCol);

    setState(() {
      editorTabManager.activeEditor!.tapCallback(filePath);
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

    // Check if file is already open
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
      // Check if file is UTF-8 encoded
      if (!await widget.fileService.isUtf8File(path)) {
        notificationService.show(
          'Cannot open binary or non-UTF8 file',
          type: NotificationType.warning,
        );
        return;
      }

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
        editors: editorTabManager
            .horizontalSplits[editorTabManager.activeRow]
                [editorTabManager.activeCol]
            .editors,
        editorTabManager: editorTabManager,
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
    _initializationFuture = _initializeServices().then((_) {
      CommandPaletteService.instance.initialize(
        // ignore: use_build_context_synchronously
        context: context,
        editorConfigService: _editorConfigService,
        editorTabManager: editorTabManager,
        onEditorClosed: onEditorClosed,
        openFile: openFile,
        fileService: widget.fileService,
      );
    });
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
      showCommandPalette: (
              [CommandPaletteMode mode = CommandPaletteMode.commands]) =>
          CommandPaletteService.instance.showCommandPalette(mode),
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
      splitVertically: editorTabManager.addVerticalSplit,
      splitHorizontally: editorTabManager.addHorizontalSplit,
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
    final targetRow = row ?? editorTabManager.activeRow;
    final targetCol = col ?? editorTabManager.activeCol;

    // Early validation
    if (targetRow >= editorTabManager.horizontalSplits.length ||
        targetCol >= editorTabManager.horizontalSplits[targetRow].length) {
      return;
    }

    // Find next focus target before closing the editor
    final nextFocusTarget = _determineNextFocusTarget(targetRow, targetCol);

    setState(() {
      // Close the editor first
      editorTabManager.closeEditor(
        index,
        row: targetRow,
        col: targetCol,
      );

      // Only try to focus next editor if there are any editors left
      if (nextFocusTarget != null) {
        final (nextRow, nextCol) = nextFocusTarget;
        if (nextRow < editorTabManager.horizontalSplits.length &&
            nextCol < editorTabManager.horizontalSplits[nextRow].length) {
          final nextSplitView =
              editorTabManager.horizontalSplits[nextRow][nextCol];
          if (nextSplitView.editors.isNotEmpty) {
            editorTabManager.setActiveEditor(
              0, // Always set to first editor to avoid index out of range
              row: nextRow,
              col: nextCol,
            );
          }
        }
      }
    });
  }

  (int, int)? _determineNextFocusTarget(int currentRow, int currentCol) {
    final splits = editorTabManager.horizontalSplits;

    // Helper function to check if a split view has editors
    bool hasSplitViewEditors(int row, int col) {
      return row < splits.length &&
          col < splits[row].length &&
          splits[row][col].editors.isNotEmpty;
    }

    // Try to focus the next editor in the same row
    if (currentCol + 1 < splits[currentRow].length &&
        hasSplitViewEditors(currentRow, currentCol + 1)) {
      return (currentRow, currentCol + 1);
    }

    // Try to focus the previous editor in the same row
    if (currentCol > 0 && hasSplitViewEditors(currentRow, currentCol - 1)) {
      return (currentRow, currentCol - 1);
    }

    // Try to focus an editor in the next row
    if (currentRow + 1 < splits.length) {
      for (int col = 0; col < splits[currentRow + 1].length; col++) {
        if (hasSplitViewEditors(currentRow + 1, col)) {
          return (currentRow + 1, col);
        }
      }
    }

    // Try to focus an editor in the previous row
    if (currentRow > 0) {
      for (int col = 0; col < splits[currentRow - 1].length; col++) {
        if (hasSplitViewEditors(currentRow - 1, col)) {
          return (currentRow - 1, col);
        }
      }
    }

    return null;
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
                                onDirectoryChanged: widget.onDirectoryChanged),
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child:
                                      editorTabManager.horizontalSplits.isEmpty
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
                                    editorConfigService: _editorConfigService),
                              ],
                            ),
                          ),
                          if (!isFileExplorerOnLeft)
                            FileExplorerContainer(
                                editorConfigService: _editorConfigService,
                                fileService: widget.fileService,
                                tapCallback: tapCallback,
                                onDirectoryChanged: widget.onDirectoryChanged),
                        ],
                      ),
                    ),
                    const StatusBar(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
