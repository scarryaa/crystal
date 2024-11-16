import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_input_handler.dart';
import 'package:crystal/services/editor/editor_keyboard_handler.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/blame_info_widget.dart';
import 'package:crystal/widgets/editor/completion_widget.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';

class EditorView extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final EditorState state;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final VoidCallback scrollToCursor;
  final Function(int index) onEditorClosed;
  final Future<void> Function() saveFileAs;
  final Future<void> Function() saveFile;
  final VoidCallback openNewTab;
  final Function(String newTerm) onSearchTermChanged;
  final String searchTerm;
  final int currentSearchTermMatch;
  final List<SearchMatch> searchTermMatches;
  final Function activeEditorIndex;
  final String fileName;
  final bool isDirty;
  final List<CompletionItem> suggestions;
  final Function(CompletionItem) onCompletionSelect;
  final int selectedSuggestionIndex;
  final GitService gitService;

  const EditorView({
    super.key,
    required this.state,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.scrollToCursor,
    required this.onEditorClosed,
    required this.saveFileAs,
    required this.saveFile,
    required this.openNewTab,
    required this.searchTerm,
    required this.searchTermMatches,
    required this.onSearchTermChanged,
    required this.currentSearchTermMatch,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.activeEditorIndex,
    required this.fileName,
    required this.isDirty,
    required this.suggestions,
    required this.onCompletionSelect,
    required this.selectedSuggestionIndex,
    required this.gitService,
  });

  @override
  State<StatefulWidget> createState() => EditorViewState();
}

class EditorViewState extends State<EditorView> {
  final FocusNode _focusNode = FocusNode();
  bool _isFocused = false;
  double _cachedMaxLineWidth = 0;
  Timer? _caretTimer;
  late final EditorInputHandler editorInputHandler;
  EditorSyntaxHighlighter? editorSyntaxHighlighter;
  late final EditorKeyboardHandler editorKeyboardHandler;
  EditorPainter? editorPainter;
  List<BlameLine>? blameInfo;

  @override
  void didUpdateWidget(EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fileName != widget.fileName) {
      editorSyntaxHighlighter = EditorSyntaxHighlighter(
        editorConfigService: widget.editorConfigService,
        editorLayoutService: widget.editorLayoutService,
        fileName: widget.fileName,
      );
      _initializeGit();
      widget.gitService.setOriginalContent(widget.state.relativePath ?? '');
    }
  }

  @override
  void initState() {
    super.initState();

    _initializeGit();

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (!_isFocused) {
          widget.state.showCaret = false;
          _stopCaretBlinking();
        } else {
          _startCaretBlinking();
        }
      });
    });

    editorInputHandler = EditorInputHandler(
        resetCaretBlink: _resetCaretBlink, requestFocus: requestFocus);

    editorKeyboardHandler = EditorKeyboardHandler(
      onSearchTermChanged: widget.onSearchTermChanged,
      updateCachedMaxLineWidth: updateCachedMaxLineWidth,
      scrollToCursor: widget.scrollToCursor,
      openConfig: _openConfig,
      openDefaultConfig: _openDefaultConfig,
      getState: () => widget.state,
      searchTerm: widget.searchTerm,
      openNewTab: widget.openNewTab,
      activeEditorIndex: () => widget.activeEditorIndex(),
      onEditorClosed: widget.onEditorClosed,
      saveFileAs: widget.saveFileAs,
      saveFile: widget.saveFile,
      updateSingleLineWidth: updateSingleLineWidth,
      isDirty: widget.isDirty,
      showCommandPalette: (
              [CommandPaletteMode mode = CommandPaletteMode.commands]) =>
          CommandPaletteService.instance.showCommandPalette(mode),
    );

    editorSyntaxHighlighter = EditorSyntaxHighlighter(
      editorConfigService: widget.editorConfigService,
      editorLayoutService: widget.editorLayoutService,
      fileName: widget.fileName,
    );
    updateCachedMaxLineWidth();
    _startCaretBlinking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _initializeGit() async {
    try {
      final blame = await widget.gitService.getBlame(widget.state.path);
      if (mounted) {
        // Add mounted check for safety
        setState(() {
          blameInfo = blame;
        });
      }
    } catch (e) {
      debugPrint('Git initialization failed: $e');
      if (mounted) {
        setState(() {
          blameInfo = [];
        });
      }
    }
  }

  Offset _getCompletionOverlayPosition() {
    final cursor = widget.state.editorCursorManager.cursors.first;
    final lineHeight = widget.editorLayoutService.config.lineHeight;

    final x = cursor.column * widget.editorLayoutService.config.charWidth;
    final y =
        (cursor.line + 1) * lineHeight - widget.verticalScrollController.offset;

    return Offset(x, y);
  }

  void updateSingleLineWidth(int lineIndex) {
    if (editorPainter == null ||
        lineIndex < 0 ||
        lineIndex >= widget.state.buffer.lines.length) {
      return;
    }

    final line = widget.state.buffer.lines[lineIndex];
    final lineWidth = editorPainter!.measureLineWidth(line);

    // Only update if this line was previously the longest
    if (lineWidth < _cachedMaxLineWidth && _isLongestLine(lineIndex)) {
      _updateMaxWidthEfficiently();
    } else if (lineWidth > _cachedMaxLineWidth) {
      _cachedMaxLineWidth = lineWidth;
      setState(() {});
    }
  }

  bool _isLongestLine(int lineIndex) {
    final currentLineWidth =
        editorPainter!.measureLineWidth(widget.state.buffer.lines[lineIndex]);
    return currentLineWidth >= _cachedMaxLineWidth;
  }

  void _updateMaxWidthEfficiently() {
    // Keep track of the longest line index to avoid full recalculation
    double maxWidth = 0;
    for (int i = 0; i < widget.state.buffer.lines.length; i++) {
      final lineWidth =
          editorPainter!.measureLineWidth(widget.state.buffer.lines[i]);
      maxWidth = math.max(maxWidth, lineWidth);
    }
    _cachedMaxLineWidth = maxWidth;
    setState(() {});
  }

  @override
  void dispose() {
    _stopCaretBlinking();
    super.dispose();
  }

  void _startCaretBlinking() {
    _caretTimer?.cancel();
    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) {
        setState(() {
          widget.state.toggleCaret();
        });
      }
    });
  }

  void _stopCaretBlinking() {
    _caretTimer?.cancel();
    _caretTimer = null;
  }

  void _resetCaretBlink() {
    if (mounted) {
      setState(() {
        widget.state.showCaret = true;
      });
      _startCaretBlinking();
    }
  }

  void updateCachedMaxLineWidth() {
    _cachedMaxLineWidth = _maxLineWidth();
  }

  double _maxLineWidth() {
    if (editorPainter == null) return 0;

    return widget.state.buffer.lines.fold<double>(0, (maxWidth, line) {
      final lineWidth =
          editorPainter == null ? 0.0 : editorPainter!.measureLineWidth(line);
      return math.max(maxWidth, lineWidth);
    });
  }

  int getVisibleLineCount() {
    int visibleCount = 0;
    final lines = widget.state.buffer.lineCount;

    for (int i = 0; i < lines; i++) {
      if (!widget.state.isLineHidden(i)) {
        visibleCount++;
      }
    }
    return visibleCount;
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.max(
      mediaQuery.size.width -
          widget.editorLayoutService.config.gutterWidth -
          (widget.editorConfigService.config.isFileExplorerVisible
              ? widget.editorConfigService.config.fileExplorerWidth
              : 0),
      _cachedMaxLineWidth + widget.editorLayoutService.config.horizontalPadding,
    );
    final height = math.max(
      mediaQuery.size.height,
      widget.editorLayoutService.config.lineHeight * getVisibleLineCount() +
          widget.editorLayoutService.config.verticalPadding,
    );
    editorPainter = EditorPainter(
      editorConfigService: widget.editorConfigService,
      editorLayoutService: widget.editorLayoutService,
      editorSyntaxHighlighter: editorSyntaxHighlighter!,
      editorState: widget.state,
      searchTerm: widget.searchTerm,
      searchTermMatches: widget.searchTermMatches,
      currentSearchTermMatch: widget.currentSearchTermMatch,
      viewportHeight: MediaQuery.of(context).size.height,
      isFocused: _isFocused,
      blameInfo: blameInfo ?? [],
    );
    widget.state.scrollState
        .updateViewportHeight(MediaQuery.of(context).size.height);

    return ListenableBuilder(
        listenable: widget.editorConfigService.themeService,
        builder: (context, _) {
          return Stack(children: [
            Container(
              color: widget.editorConfigService.themeService.currentTheme
                      ?.background ??
                  Colors.white,
              child: Focus(
                focusNode: _focusNode,
                onKeyEvent: (node, event) {
                  _handleKeyEventAsync(node, event);
                  return KeyEventResult.handled;
                },
                autofocus: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => editorInputHandler.handleTap(
                      details,
                      widget.verticalScrollController.offset,
                      widget.horizontalScrollController.offset,
                      editorPainter,
                      widget.state),
                  onPanStart: (details) => editorInputHandler.handleDragStart(
                      details,
                      widget.verticalScrollController.offset,
                      widget.horizontalScrollController.offset,
                      editorPainter,
                      widget.state),
                  onPanUpdate: (details) => editorInputHandler.handleDragUpdate(
                      details,
                      widget.verticalScrollController.offset,
                      widget.horizontalScrollController.offset,
                      editorPainter,
                      widget.state),
                  child: ScrollbarTheme(
                    data: ScrollbarThemeData(
                      thumbColor: WidgetStateProperty.all(widget
                                  .editorConfigService
                                  .themeService
                                  .currentTheme !=
                              null
                          ? widget.editorConfigService.themeService
                              .currentTheme!.border
                              .withOpacity(0.65)
                          : Colors.grey[600]!.withOpacity(0.65)),
                    ),
                    child: Scrollbar(
                      controller: widget.verticalScrollController,
                      thickness: 10,
                      radius: const Radius.circular(0),
                      child: Scrollbar(
                        controller: widget.horizontalScrollController,
                        thickness: 10,
                        radius: const Radius.circular(0),
                        notificationPredicate: (notification) =>
                            notification.depth == 1,
                        child: ScrollConfiguration(
                          behavior: const ScrollBehavior()
                              .copyWith(scrollbars: false),
                          child: SingleChildScrollView(
                            controller: widget.verticalScrollController,
                            child: SingleChildScrollView(
                              controller: widget.horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: RepaintBoundary(
                                child: Stack(
                                  children: [
                                    CustomPaint(
                                      painter: editorPainter,
                                      size: Size(width, height),
                                    ),
                                    if (blameInfo != null &&
                                        blameInfo!.isNotEmpty)
                                      Positioned.fill(
                                        child: BlameInfoWidget(
                                          editorConfigService:
                                              widget.editorConfigService,
                                          editorLayoutService:
                                              widget.editorLayoutService,
                                          blameInfo: blameInfo!,
                                          editorState: widget.state,
                                          size: Size(width, height),
                                          gitService: widget.gitService,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (widget.state.showCompletions)
              ListenableBuilder(
                listenable: widget.state,
                builder: (context, _) {
                  return CompletionOverlay(
                    suggestions: widget.suggestions,
                    onSelect: widget.onCompletionSelect,
                    position: _getCompletionOverlayPosition(),
                    selectedIndex: widget.selectedSuggestionIndex,
                    editorConfigService: widget.editorConfigService,
                  );
                },
              )
          ]);
        });
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  Future<void> _handleKeyEventAsync(FocusNode node, KeyEvent event) async {
    await _handleKeyEvent(node, event);
  }

  Future<KeyEventResult> _handleKeyEvent(FocusNode node, KeyEvent event) async {
    _resetCaretBlink();
    return await editorKeyboardHandler.handleKeyEvent(node, event);
  }

  Future<void> _openConfig() async {
    final configPath = await ConfigPaths.getConfigFilePath();
    await widget.state.tapCallback(configPath);
  }

  Future<void> _openDefaultConfig() async {
    final defaultConfigPath = await ConfigPaths.getDefaultConfigFilePath();
    await widget.state.tapCallback(defaultConfigPath);
  }
}
