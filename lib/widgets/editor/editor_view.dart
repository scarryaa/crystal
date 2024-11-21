import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/commands/editing_commands.dart';
import 'package:crystal/models/editor/commands/file_commands.dart';
import 'package:crystal/models/editor/commands/navigation_commands.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/git_models.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/models/word_info.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_input_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/editor_keyboard_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/file_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/navigation_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/text_editing_handler.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/blame_info_widget.dart';
import 'package:crystal/widgets/editor/completion_widget.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:crystal/widgets/hover_info_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextRange;

class EditorView extends StatefulWidget {
  final EditorViewConfig config;

  const EditorView({
    super.key,
    required this.config,
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
  Position? _lastCursorPosition;
  Timer? _cursorMoveTimer;
  bool _isCursorMovementRecent = false;
  List<lsp_models.Diagnostic>? hoveredInfo;

  void _handleCursorMove() {
    if (widget.config.state.cursors.isEmpty) return;

    final currentCursor = widget.config.state.cursors.first;
    final currentPosition = Position(
      line: currentCursor.line,
      column: currentCursor.column,
    );

    if (_lastCursorPosition != currentPosition) {
      _lastCursorPosition = currentPosition;
      _isCursorMovementRecent = true;
      _cancelHoverOperations();

      // Reset the cursor movement flag after a short delay
      _cursorMoveTimer?.cancel();
      _cursorMoveTimer = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isCursorMovementRecent = false;
          });
        }
      });
    }
  }

  void _cancelHoverOperations() {
    _hoverTimer?.cancel();
    _wordHighlightTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isHoveringWord = false;
      _hoveredWordRange = null;
      _lastHoveredWord = null;
      _hoverPosition = null;
    });

    EditorEventBus.emit(HoverEvent(
      line: -100,
      character: -100,
      content: '',
    ));
  }

  @override
  void didUpdateWidget(EditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.fileConfig.fileName !=
        widget.config.fileConfig.fileName) {
      editorSyntaxHighlighter = EditorSyntaxHighlighter(
        editorConfigService: widget.config.services.configService,
        editorLayoutService: widget.config.services.layoutService,
        fileName: widget.config.fileConfig.fileName,
      );
      _initializeGit();
      widget.config.services.gitService
          .setOriginalContent(widget.config.state.relativePath ?? '');
    }
  }

  @override
  void initState() {
    super.initState();

    EditorEventBus.on<CursorEvent>().listen((_) {
      _handleCursorMove();
    });

    widget.config.scrollConfig.verticalController.addListener(_hidePopups);
    widget.config.scrollConfig.horizontalController.addListener(_hidePopups);
    _initializeGit();

    EditorEventBus.on<TextEvent>().listen((_) {
      if (!_isHoveringPopup) {
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
      }
    });

    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
        if (!_isFocused) {
          widget.config.state.showCaret = false;
          _stopCaretBlinking();
        } else {
          _startCaretBlinking();
        }
      });
    });

    editorInputHandler = EditorInputHandler(
        resetCaretBlink: _resetCaretBlink, requestFocus: requestFocus);

    editorKeyboardHandler = EditorKeyboardHandler(
      // Base handlers
      fileHandler: FileHandler(
        getState: () => widget.config.state,
        scrollToCursor: widget.config.scrollConfig.scrollToCursor,
        isDirty: widget.config.fileConfig.isDirty,
        fileCommands: FileCommands(
          saveFile: widget.config.fileConfig.saveFile,
          saveFileAs: widget.config.fileConfig.saveFileAs,
          openConfig: _openConfig,
          openDefaultConfig: _openDefaultConfig,
          openNewTab: widget.config.fileConfig.openNewTab,
        ),
        onEditorClosed: widget.config.fileConfig.onEditorClosed,
        activeEditorIndex: () => widget.config.fileConfig.activeEditorIndex,
      ),
      navigationHandler: NavigationHandler(
        getState: () => widget.config.state,
        scrollToCursor: widget.config.scrollConfig.scrollToCursor,
        navigationCommands: NavigationCommands(
          scrollToCursor: widget.config.scrollConfig.scrollToCursor,
          moveCursorUp: widget.config.state.moveCursorUp,
          moveCursorDown: widget.config.state.moveCursorDown,
          moveCursorLeft: widget.config.state.moveCursorLeft,
          moveCursorRight: widget.config.state.moveCursorRight,
          moveCursorToLineStart: widget.config.state.moveCursorToLineStart,
          moveCursorToLineEnd: widget.config.state.moveCursorToLineEnd,
          moveCursorToDocumentStart:
              widget.config.state.moveCursorToDocumentStart,
          moveCursorToDocumentEnd: widget.config.state.moveCursorToDocumentEnd,
          moveCursorPageUp: widget.config.state.moveCursorPageUp,
          moveCursorPageDown: widget.config.state.moveCursorPageDown,
        ),
      ),
      textEditingHandler: TextEditingHandler(
        getState: () => widget.config.state,
        scrollToCursor: widget.config.scrollConfig.scrollToCursor,
        editingCommands: EditingCommands(
          copy: widget.config.state.copy,
          cut: widget.config.state.cut,
          paste: widget.config.state.paste,
          selectAll: widget.config.state.selectAll,
          backspace: widget.config.state.backspace,
          delete: widget.config.state.delete,
          insertNewLine: widget.config.state.insertNewLine,
          insertTab: widget.config.state.insertTab,
          backTab: widget.config.state.backTab,
          insertChar: widget.config.state.insertChar,
          getLastPastedLineCount: widget.config.state.getLastPastedLineCount,
          getSelectedLineRange: widget.config.state.getSelectedLineRange,
        ),
        updateSingleLineWidth: updateSingleLineWidth,
        onSearchTermChanged: widget.config.searchConfig.onSearchTermChanged,
        searchTerm: widget.config.searchConfig.searchTerm,
      ),
      // Core properties
      getState: () => widget.config.state,
      onSearchTermChanged: widget.config.searchConfig.onSearchTermChanged,
      searchTerm: widget.config.searchConfig.searchTerm,
      showCommandPalette: (
              [CommandPaletteMode mode = CommandPaletteMode.commands]) =>
          CommandPaletteService.instance.showCommandPalette(mode),
    );

    editorSyntaxHighlighter = EditorSyntaxHighlighter(
      editorConfigService: widget.config.services.configService,
      editorLayoutService: widget.config.services.layoutService,
      fileName: widget.config.fileConfig.fileName,
    );
    updateCachedMaxLineWidth();
    _startCaretBlinking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  Future<void> _initializeGit() async {
    try {
      final blame = await widget.config.services.gitService
          .getBlame(widget.config.state.path);
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
    final cursor = widget.config.state.cursors.first;
    final lineHeight = widget.config.services.layoutService.config.lineHeight;

    final x =
        cursor.column * widget.config.services.layoutService.config.charWidth;
    final y = (cursor.line + 1) * lineHeight -
        widget.config.scrollConfig.verticalController.offset;

    return Offset(x, y);
  }

  void updateSingleLineWidth(int lineIndex) {
    if (editorPainter == null ||
        lineIndex < 0 ||
        lineIndex >= widget.config.state.buffer.lines.length) {
      return;
    }

    final line = widget.config.state.buffer.lines[lineIndex];
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
    final currentLineWidth = editorPainter!
        .measureLineWidth(widget.config.state.buffer.lines[lineIndex]);
    return currentLineWidth >= _cachedMaxLineWidth;
  }

  void _updateMaxWidthEfficiently() {
    // Keep track of the longest line index to avoid full recalculation
    double maxWidth = 0;
    for (int i = 0; i < widget.config.state.buffer.lines.length; i++) {
      final lineWidth =
          editorPainter!.measureLineWidth(widget.config.state.buffer.lines[i]);
      maxWidth = math.max(maxWidth, lineWidth);
    }
    _cachedMaxLineWidth = maxWidth;
    setState(() {});
  }

  @override
  void dispose() {
    _cursorMoveTimer?.cancel();
    _hoverTimer?.cancel();
    _wordHighlightTimer?.cancel();
    widget.config.scrollConfig.verticalController.removeListener(_hidePopups);
    widget.config.scrollConfig.horizontalController.removeListener(_hidePopups);
    _stopCaretBlinking();
    _focusNode.dispose();
    super.dispose();
  }

  void _startCaretBlinking() {
    if (mounted) {
      _caretTimer?.cancel();
      _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        setState(() {
          widget.config.state.toggleCaret();
        });
      });
    }
  }

  void _stopCaretBlinking() {
    _caretTimer?.cancel();
    _caretTimer = null;
  }

  void _resetCaretBlink() {
    if (mounted) {
      setState(() {
        widget.config.state.showCaret = true;
      });
      _startCaretBlinking();
    }
  }

  void updateCachedMaxLineWidth() {
    _cachedMaxLineWidth = _maxLineWidth();
  }

  double _maxLineWidth() {
    if (editorPainter == null) return 0;

    return widget.config.state.buffer.lines.fold<double>(0, (maxWidth, line) {
      final lineWidth =
          editorPainter == null ? 0.0 : editorPainter!.measureLineWidth(line);
      return math.max(maxWidth, lineWidth);
    });
  }

  int getVisibleLineCount() {
    int visibleCount = 0;
    final lines = widget.config.state.buffer.lineCount;

    for (int i = 0; i < lines; i++) {
      if (!widget.config.state.isLineHidden(i)) {
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
          widget.config.services.layoutService.config.gutterWidth -
          (widget.config.services.configService.config.isFileExplorerVisible
              ? widget.config.services.configService.config.fileExplorerWidth
              : 0),
      _cachedMaxLineWidth +
          widget.config.services.layoutService.config.horizontalPadding,
    );
    final height = math.max(
      mediaQuery.size.height,
      widget.config.services.layoutService.config.lineHeight *
              getVisibleLineCount() +
          widget.config.services.layoutService.config.verticalPadding,
    );

    String currentWord = '';
    List<TextRange> currentWordOccurrences = [];
    if (widget.config.state.cursors.isNotEmpty) {
      final cursor = widget.config.state.cursors.first;
      final wordRange =
          widget.config.state.getWordRangeAt(cursor.line, cursor.column);
      if (wordRange != null) {
        currentWord = widget.config.state.buffer.getTextInRange(wordRange);
        currentWordOccurrences =
            widget.config.state.findAllOccurrences(currentWord);
      }
    }

    editorPainter = EditorPainter(
      editorConfigService: widget.config.services.configService,
      editorLayoutService: widget.config.services.layoutService,
      editorSyntaxHighlighter: editorSyntaxHighlighter!,
      editorState: widget.config.state,
      searchTerm: widget.config.searchConfig.searchTerm,
      searchTermMatches: widget.config.searchConfig.matches,
      currentSearchTermMatch: widget.config.searchConfig.currentMatch,
      viewportHeight: MediaQuery.of(context).size.height,
      isFocused: _isFocused,
      blameInfo: blameInfo ?? [],
      hoverPosition: _hoverPosition,
      hoveredWordRange: _hoveredWordRange,
      currentWordOccurrences: currentWordOccurrences,
      hoveredInfo: hoveredInfo,
    );
    widget.config.state.scrollState
        .updateViewportHeight(MediaQuery.of(context).size.height);
    widget.config.state.scrollState
        .updateViewportWidth(MediaQuery.of(context).size.width);

    return ListenableBuilder(
        listenable: Listenable.merge([
          widget.config.services.configService.themeService,
          widget.config.globalHoverState,
        ]),
        builder: (context, _) {
          return Stack(children: [
            Container(
                color: widget.config.services.configService.themeService
                        .currentTheme?.background ??
                    Colors.white,
                child: Focus(
                  focusNode: _focusNode,
                  onKeyEvent: (node, event) {
                    _handleKeyEventAsync(node, event);
                    return KeyEventResult.handled;
                  },
                  autofocus: true,
                  child: MouseRegion(
                    onEnter: (_) => widget.config.globalHoverState
                        .setActiveEditor(widget.config.row, widget.config.col),
                    onExit: (_) {
                      _wordHighlightTimer?.cancel();

                      if (!_isHoveringPopup) {
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (!_isHoveringPopup && mounted) {
                            widget.config.globalHoverState.clearActiveEditor();
                          }
                        });
                      }
                    },
                    onHover: (PointerHoverEvent event) {
                      if (_isTyping || _isCursorMovementRecent) {
                        _handleEmptyWord();
                        return;
                      }

                      final cursorPosition = _getPositionFromOffset(Offset(
                        event.localPosition.dx +
                            widget.config.scrollConfig.horizontalController
                                .offset,
                        event.localPosition.dy +
                            widget
                                .config.scrollConfig.verticalController.offset,
                      ));

                      final wordInfo = _getWordInfoAtPosition(cursorPosition);

                      // Check if the hovered word is different from the last hovered word
                      if (_lastHoveredWord?.word != wordInfo?.word ||
                          _lastHoveredWord?.startColumn !=
                              wordInfo?.startColumn ||
                          _lastHoveredWord?.startLine != wordInfo?.startLine) {
                        if (!_isHoveringPopup) {
                          _handleEmptyWord();
                        }
                      }

                      // Cancel any existing timers
                      _wordHighlightTimer?.cancel();

                      // Handle the case where no word is hovered
                      if (wordInfo == null) {
                        _wordHighlightTimer =
                            Timer(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            _handleEmptyWord();
                          }
                        });
                        return;
                      }

                      // Update the last hovered word and hover position
                      _lastHoveredWord = wordInfo;
                      setState(() {
                        _hoverPosition = event.localPosition;
                      });

                      // Set a new timer to handle the word highlight and diagnostics
                      _wordHighlightTimer =
                          Timer(const Duration(milliseconds: 300), () async {
                        if (!mounted) return;

                        setState(() {
                          _isHoveringWord = true;
                          _hoveredWordRange = TextRange(
                            start: Position(
                              line: cursorPosition.line,
                              column: wordInfo.startColumn,
                            ),
                            end: Position(
                              line: cursorPosition.line,
                              column: wordInfo.endColumn,
                            ),
                          );
                        });

                        // Get the diagnostics for the new word
                        final diagnostics = await widget.config.state
                            .showDiagnostics(
                                cursorPosition.line, wordInfo.startColumn);

                        // Update state with the diagnostics if still mounted
                        setState(() {
                          hoveredInfo = diagnostics;
                        });

                        await widget.config.state.showHover(
                            cursorPosition.line, wordInfo.startColumn);
                      });
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        _hidePopups();
                        _cancelHoverOperations();
                        editorInputHandler.handleTap(
                          details,
                          widget.config.scrollConfig.verticalController.offset,
                          widget
                              .config.scrollConfig.horizontalController.offset,
                          editorPainter,
                          widget.config.state,
                        );
                      },
                      onPanStart: (details) =>
                          editorInputHandler.handleDragStart(
                        details,
                        widget.config.scrollConfig.verticalController.offset,
                        widget.config.scrollConfig.horizontalController.offset,
                        editorPainter,
                        widget.config.state,
                      ),
                      onPanUpdate: (details) =>
                          editorInputHandler.handleDragUpdate(
                        details,
                        widget.config.scrollConfig.verticalController.offset,
                        widget.config.scrollConfig.horizontalController.offset,
                        editorPainter,
                        widget.config.state,
                      ),
                      child: ScrollbarTheme(
                        data: ScrollbarThemeData(
                          thumbColor: WidgetStateProperty.all(widget
                                      .config
                                      .services
                                      .configService
                                      .themeService
                                      .currentTheme !=
                                  null
                              ? widget.config.services.configService
                                  .themeService.currentTheme!.border
                                  .withOpacity(0.65)
                              : Colors.grey[600]!.withOpacity(0.65)),
                        ),
                        child: Scrollbar(
                          controller:
                              widget.config.scrollConfig.verticalController,
                          thickness: 10,
                          radius: const Radius.circular(0),
                          child: Scrollbar(
                            controller:
                                widget.config.scrollConfig.horizontalController,
                            thickness: 10,
                            radius: const Radius.circular(0),
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: ScrollConfiguration(
                              behavior: const ScrollBehavior()
                                  .copyWith(scrollbars: false),
                              child: SingleChildScrollView(
                                controller: widget
                                    .config.scrollConfig.verticalController,
                                child: SingleChildScrollView(
                                  controller: widget
                                      .config.scrollConfig.horizontalController,
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
                                              editorConfigService: widget.config
                                                  .services.configService,
                                              editorLayoutService: widget.config
                                                  .services.layoutService,
                                              blameInfo: blameInfo!,
                                              editorState: widget.config.state,
                                              size: Size(width, height),
                                              gitService: widget
                                                  .config.services.gitService,
                                            ),
                                          ),
                                        HoverInfoWidget(
                                          editorState: widget.config.state,
                                          editorLayoutService: widget
                                              .config.services.layoutService,
                                          editorConfigService: widget
                                              .config.services.configService,
                                          isHoveringWord: _isHoveringWord,
                                          onHoverPopup: onHoverPopup,
                                          onLeavePopup: onLeavePopup,
                                          row: widget.config.row,
                                          col: widget.config.col,
                                          globalHoverState:
                                              widget.config.globalHoverState,
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
            if (widget.config.state.showCompletions)
              ListenableBuilder(
                listenable: widget.config.state,
                builder: (context, _) {
                  return CompletionOverlay(
                    suggestions: widget.config.completionConfig.suggestions,
                    onSelect: widget.config.completionConfig.onSelect,
                    position: _getCompletionOverlayPosition(),
                    selectedIndex: widget.config.completionConfig.selectedIndex,
                    editorConfigService: widget.config.services.configService,
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
    final line = widget.config.state.buffer.getLine(position.line);
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
        (offset.dy / widget.config.services.layoutService.config.lineHeight)
            .floor();
    final column =
        (offset.dx / widget.config.services.layoutService.config.charWidth)
            .floor();
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

    if (!_isHoveringPopup) {
      _cancelHoverOperations();
    }

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
    await widget.config.state.tapCallback(configPath);
  }

  Future<void> _openDefaultConfig() async {
    final defaultConfigPath = await ConfigPaths.getDefaultConfigFilePath();
    await widget.config.state.tapCallback(defaultConfigPath);
  }
}
