import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/models/git_models.dart';
import 'package:crystal/models/global_hover_state.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/models/word_info.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_input_handler.dart';
import 'package:crystal/services/editor/editor_keyboard_handler.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/blame_info_widget.dart';
import 'package:crystal/widgets/editor/completion_widget.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:crystal/widgets/hover_info_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextRange;

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
  final int row;
  final int col;
  final GlobalHoverState globalHoverState;

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
    required this.row,
    required this.col,
    required this.globalHoverState,
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
  Timer? _hoverTimer;
  bool _isHoveringPopup = false;
  bool _isHoveringWord = false;
  WordInfo? _lastHoveredWord;
  bool _isTyping = false;
  Offset? _hoverPosition;
  TextRange? _hoveredWordRange;
  Timer? _wordHighlightTimer;

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

    widget.verticalScrollController.addListener(_hidePopups);
    widget.horizontalScrollController.addListener(_hidePopups);
    _initializeGit();

    EditorEventBus.on<TextEvent>().listen((_) {
      setState(() {
        _isHoveringPopup = false;
        _isHoveringWord = false;
      });
      // Force emit a hover clear event
      EditorEventBus.emit(HoverEvent(
        line: -100,
        character: -100,
        content: '',
      ));
    });

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
    widget.verticalScrollController.removeListener(_hidePopups);
    widget.horizontalScrollController.removeListener(_hidePopups);
    _hoverTimer?.cancel();
    _wordHighlightTimer?.cancel();
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

  void onHoverPopup() {
    setState(() {
      _isHoveringPopup = true;
    });
  }

  void onLeavePopup() {
    if (mounted) {
      setState(() {
        _isHoveringPopup = false;
      });
    }
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

    String currentWord = '';
    List<TextRange> currentWordOccurrences = [];
    if (widget.state.editorCursorManager.cursors.isNotEmpty) {
      final cursor = widget.state.editorCursorManager.cursors.first;
      final wordRange = widget.state.getWordRangeAt(cursor.line, cursor.column);
      if (wordRange != null) {
        currentWord = widget.state.buffer.getTextInRange(wordRange);
        currentWordOccurrences = widget.state.findAllOccurrences(currentWord);
      }
    }

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
      hoverPosition: _hoverPosition,
      hoveredWordRange: _hoveredWordRange,
      currentWordOccurrences: currentWordOccurrences,
    );
    widget.state.scrollState
        .updateViewportHeight(MediaQuery.of(context).size.height);
    widget.state.scrollState
        .updateViewportWidth(MediaQuery.of(context).size.width);

    return ListenableBuilder(
        listenable: Listenable.merge([
          widget.editorConfigService.themeService,
          widget.globalHoverState,
        ]),
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
                  child: MouseRegion(
                    onEnter: (_) => widget.globalHoverState
                        .setActiveEditor(widget.row, widget.col),
                    onExit: (_) {
                      _wordHighlightTimer?.cancel();

                      if (!_isHoveringPopup) {
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (!_isHoveringPopup && mounted) {
                            widget.globalHoverState.clearActiveEditor();
                          }
                        });
                      }
                    },
                    onHover: (PointerHoverEvent event) {
                      if (_isTyping) return;

                      final cursorPosition = _getPositionFromOffset(Offset(
                        event.localPosition.dx +
                            widget.horizontalScrollController.offset,
                        event.localPosition.dy +
                            widget.verticalScrollController.offset,
                      ));

                      final wordInfo = _getWordInfoAtPosition(cursorPosition);
                      if ((_lastHoveredWord?.word == wordInfo?.word &&
                          _lastHoveredWord?.startColumn ==
                              wordInfo?.startColumn &&
                          _lastHoveredWord?.startLine == wordInfo?.startLine)) {
                        return;
                      }

                      if (wordInfo == null) {
                        _wordHighlightTimer =
                            Timer(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _handleEmptyWord();
                          }
                        });
                        return;
                      }

                      _lastHoveredWord = wordInfo;
                      setState(() {
                        _hoverPosition = event.localPosition;
                      });

                      _wordHighlightTimer?.cancel();

                      _wordHighlightTimer =
                          Timer(const Duration(milliseconds: 300), () {
                        if (!mounted) return;

                        setState(() {
                          _isHoveringWord = true;
                          _hoveredWordRange = TextRange(
                            start: Position(
                                line: cursorPosition.line,
                                column: wordInfo.startColumn),
                            end: Position(
                                line: cursorPosition.line,
                                column: wordInfo.endColumn),
                          );
                        });

                        widget.state.showDiagnostics(
                            cursorPosition.line, wordInfo.startColumn);

                        widget.state.showHover(
                            cursorPosition.line, wordInfo.startColumn);
                      });
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _hidePopups();
                        editorInputHandler.handleTap(
                          details,
                          widget.verticalScrollController.offset,
                          widget.horizontalScrollController.offset,
                          editorPainter,
                          widget.state,
                        );
                      },
                      onPanStart: (details) =>
                          editorInputHandler.handleDragStart(
                        details,
                        widget.verticalScrollController.offset,
                        widget.horizontalScrollController.offset,
                        editorPainter,
                        widget.state,
                      ),
                      onPanUpdate: (details) =>
                          editorInputHandler.handleDragUpdate(
                        details,
                        widget.verticalScrollController.offset,
                        widget.horizontalScrollController.offset,
                        editorPainter,
                        widget.state,
                      ),
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
                                        HoverInfoWidget(
                                          editorState: widget.state,
                                          editorLayoutService:
                                              widget.editorLayoutService,
                                          editorConfigService:
                                              widget.editorConfigService,
                                          isHoveringWord: _isHoveringWord,
                                          onHoverPopup: onHoverPopup,
                                          onLeavePopup: onLeavePopup,
                                          row: widget.row,
                                          col: widget.col,
                                          globalHoverState:
                                              widget.globalHoverState,
                                        )
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
                )),
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
              ),
          ]);
        });
  }

  void _hidePopups() {
    if (mounted) {
      setState(() {
        _isHoveringPopup = false;
        _isHoveringWord = false;
        _hoveredWordRange = null;
      });
      EditorEventBus.emit(HoverEvent(
        line: -100,
        character: -100,
        content: '',
      ));
    }
  }

  void _handleEmptyWord() {
    _isHoveringWord = false;
    EditorEventBus.emit(HoverEvent(
      line: -100,
      character: -100,
      content: '',
    ));

    setState(() {
      _hoveredWordRange = null;
      _lastHoveredWord = null;
    });
  }

  WordInfo? _getWordInfoAtPosition(Position position) {
    final line = widget.state.buffer.getLine(position.line);
    final wordBoundaryPattern = RegExp(r'[a-zA-Z0-9_]+');
    final matches = wordBoundaryPattern.allMatches(line);

    for (final match in matches) {
      if (match.start <= position.column && position.column <= match.end) {
        return WordInfo(
          word: line.substring(match.start, match.end),
          startColumn: match.start,
          endColumn: match.end,
          startLine: position.line,
        );
      }
    }
    return null;
  }

  Position _getPositionFromOffset(Offset offset) {
    final line =
        (offset.dy / widget.editorLayoutService.config.lineHeight).floor();
    final column =
        (offset.dx / widget.editorLayoutService.config.charWidth).floor();
    return Position(line: line, column: column);
  }

  void requestFocus() {
    _focusNode.requestFocus();
  }

  Future<void> _handleKeyEventAsync(FocusNode node, KeyEvent event) async {
    await _handleKeyEvent(node, event);
  }

  Future<KeyEventResult> _handleKeyEvent(FocusNode node, KeyEvent event) async {
    _resetCaretBlink();
    _isTyping = true;

    // Reset typing state after a delay
    Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isTyping = false;
        });
      }
    });

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
