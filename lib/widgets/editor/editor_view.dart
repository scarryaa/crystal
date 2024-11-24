import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/editor_managers.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/models/word_info.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/blame_info_widget.dart';
import 'package:crystal/widgets/editor/completion_widget.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:crystal/widgets/hover_info_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide TextRange hide FocusManager;

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
  EditorSyntaxHighlighter? editorSyntaxHighlighter;
  late final EditorManagers managers = EditorManagers(
      config: widget.config,
      requestFocus: requestFocus,
      resetCaretBlink: () => managers.focus.resetCaretBlink());

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
      managers.git.initializeGit();
      widget.config.services.gitService
          .setOriginalContent(widget.config.state.relativePath ?? '');
    }
  }

  @override
  void initState() {
    super.initState();

    EditorEventBus.on<CursorEvent>().listen((_) {
      managers.cursor.handleCursorMove();
    });

    widget.config.scrollConfig.verticalController
        .addListener(managers.hover.hidePopups);
    widget.config.scrollConfig.horizontalController
        .addListener(managers.hover.hidePopups);
    managers.git.initializeGit();

    EditorEventBus.on<TextEvent>().listen((_) {
      if (!managers.hover.isHoveringPopup) {
        setState(() {
          managers.hover.isHoveringPopup = false;
          managers.hover.isHoveringWord = false;
        });
        // Force emit a hover clear event
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
        ));
      }
    });

    managers.focus.focusNode.addListener(() {
      setState(() {
        managers.focus.isFocused = managers.focus.focusNode.hasFocus;
        if (!managers.focus.isFocused) {
          widget.config.state.showCaret = false;
          managers.focus.stopCaretBlinking();
        } else {
          managers.focus.startCaretBlinking();
        }
      });
    });

    editorSyntaxHighlighter = EditorSyntaxHighlighter(
      editorConfigService: widget.config.services.configService,
      editorLayoutService: widget.config.services.layoutService,
      fileName: widget.config.fileConfig.fileName,
    );

    managers.painter.updateCachedMaxLineWidth();
    managers.focus.startCaretBlinking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      managers.focus.focusNode.requestFocus();
    });
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

  @override
  void dispose() {
    managers.dispose();
    widget.config.scrollConfig.verticalController
        .removeListener(managers.hover.hidePopups);
    widget.config.scrollConfig.horizontalController
        .removeListener(managers.hover.hidePopups);
    super.dispose();
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
      managers.hover.isHoveringPopup = true;
    });
  }

  void onLeavePopup() {
    if (mounted) {
      setState(() {
        managers.hover.isHoveringPopup = false;
      });
    }
  }

  void updateCachedMaxLineWidth() =>
      managers.painter.updateCachedMaxLineWidth();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.config.services.configService.themeService,
        widget.config.globalHoverState,
      ]),
      builder: (context, _) => Stack(
        children: [
          _buildEditorContainer(context),
          if (widget.config.state.showCompletions) _buildCompletionOverlay(),
        ],
      ),
    );
  }

  Widget _buildEditorContainer(BuildContext context) {
    return Container(
      color: widget.config.services.configService.themeService.currentTheme
              ?.background ??
          Colors.white,
      child: Focus(
        focusNode: managers.focus.focusNode,
        onKeyEvent: _handleKeyEvent,
        autofocus: true,
        child: _buildMouseRegion(),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    managers.keyEvent.handleKeyEventAsync(node, event);
    return KeyEventResult.handled;
  }

  Widget _buildMouseRegion() {
    return MouseRegion(
      onEnter: (_) => widget.config.globalHoverState
          .setActiveEditor(widget.config.row, widget.config.col),
      onExit: _handleMouseExit,
      onHover: _handleMouseHover,
      child: _buildGestureDetector(),
    );
  }

  void _handleMouseExit(_) {
    managers.hover.wordHighlightTimer?.cancel();

    if (!managers.hover.isHoveringPopup) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (!managers.hover.isHoveringPopup && mounted) {
          widget.config.globalHoverState.clearActiveEditor();
        }
      });
    }
  }

  Widget _buildGestureDetector() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _handleTapDown,
      onPanStart: _handlePanStart,
      onPanUpdate: _handlePanUpdate,
      child: _buildScrollbars(),
    );
  }

  void _handleTapDown(TapDownDetails details) {
    managers.hover.hidePopups();
    managers.hover.cancelHoverOperations();
    managers.input.handleTap(
      details,
      widget.config.scrollConfig.verticalController.offset,
      widget.config.scrollConfig.horizontalController.offset,
      managers.painter.editorPainter,
      widget.config.state,
    );
  }

  void _handlePanStart(DragStartDetails details) {
    managers.input.handleDragStart(
      details,
      widget.config.scrollConfig.verticalController.offset,
      widget.config.scrollConfig.horizontalController.offset,
      managers.painter.editorPainter,
      widget.config.state,
    );
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    managers.input.handleDragUpdate(
      details,
      widget.config.scrollConfig.verticalController.offset,
      widget.config.scrollConfig.horizontalController.offset,
      managers.painter.editorPainter,
      widget.config.state,
    );
  }

  Widget _buildScrollbars() {
    return ScrollbarTheme(
      data: _getScrollbarThemeData(),
      child: _buildVerticalScrollbar(),
    );
  }

  ScrollbarThemeData _getScrollbarThemeData() {
    return ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(
        widget.config.services.configService.themeService.currentTheme != null
            ? widget
                .config.services.configService.themeService.currentTheme!.border
                .withOpacity(0.65)
            : Colors.grey[600]!.withOpacity(0.65),
      ),
    );
  }

  Widget _buildVerticalScrollbar() {
    return Scrollbar(
      controller: widget.config.scrollConfig.verticalController,
      thickness: 10,
      radius: const Radius.circular(0),
      child: _buildHorizontalScrollbar(),
    );
  }

  Widget _buildHorizontalScrollbar() {
    return Scrollbar(
      controller: widget.config.scrollConfig.horizontalController,
      thickness: 10,
      radius: const Radius.circular(0),
      notificationPredicate: (notification) => notification.depth == 1,
      child: _buildScrollContent(),
    );
  }

  Widget _buildScrollContent() {
    final Size size = _calculateEditorSize(context);

    return ScrollConfiguration(
      behavior: const ScrollBehavior().copyWith(scrollbars: false),
      child: SingleChildScrollView(
        controller: widget.config.scrollConfig.verticalController,
        child: SingleChildScrollView(
          controller: widget.config.scrollConfig.horizontalController,
          scrollDirection: Axis.horizontal,
          child: RepaintBoundary(
            child: _buildEditorStack(size),
          ),
        ),
      ),
    );
  }

  Size _calculateEditorSize(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.max(
      mediaQuery.size.width -
          widget.config.services.layoutService.config.gutterWidth -
          (widget.config.services.configService.config.isFileExplorerVisible
              ? widget.config.services.configService.config.fileExplorerWidth
              : 0),
      managers.painter.cachedMaxLineWidth +
          widget.config.services.layoutService.config.horizontalPadding,
    );
    final height = math.max(
      mediaQuery.size.height,
      widget.config.services.layoutService.config.lineHeight *
              getVisibleLineCount() +
          widget.config.services.layoutService.config.verticalPadding,
    );
    return Size(width, height);
  }

  Widget _buildEditorStack(Size size) {
    _updateEditorState(size);
    return Stack(
      children: [
        CustomPaint(
          painter: managers.painter.editorPainter,
          size: size,
        ),
        if (managers.git.blameInfo != null &&
            managers.git.blameInfo!.isNotEmpty)
          _buildBlameInfoWidget(size),
        _buildHoverInfoWidget(),
      ],
    );
  }

  void _updateEditorState(Size size) {
    _updateEditorPainter();
    widget.config.state.scrollState
        .updateViewportHeight(MediaQuery.of(context).size.height);
    widget.config.state.scrollState
        .updateViewportWidth(MediaQuery.of(context).size.width);
  }

  void _updateEditorPainter() {
    final currentWordInfo = _getCurrentWordInfo();
    managers.painter.editorPainter = EditorPainter(
      editorConfigService: widget.config.services.configService,
      editorLayoutService: widget.config.services.layoutService,
      editorSyntaxHighlighter: editorSyntaxHighlighter!,
      editorState: widget.config.state,
      searchTerm: widget.config.searchConfig.searchTerm,
      searchTermMatches: widget.config.searchConfig.matches,
      currentSearchTermMatch: widget.config.searchConfig.currentMatch,
      viewportHeight: MediaQuery.of(context).size.height,
      isFocused: managers.focus.isFocused,
      blameInfo: managers.git.blameInfo ?? [],
      hoverPosition: managers.hover.hoverPosition,
      hoveredWordRange: managers.hover.hoveredWordRange,
      currentWordOccurrences: currentWordInfo.$2,
      hoveredInfo: managers.hover.hoveredInfo,
    );
  }

  (String, List<TextRange>) _getCurrentWordInfo() {
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
    return (currentWord, currentWordOccurrences);
  }

  Widget _buildBlameInfoWidget(Size size) {
    return Positioned.fill(
      child: BlameInfoWidget(
        editorConfigService: widget.config.services.configService,
        editorLayoutService: widget.config.services.layoutService,
        blameInfo: managers.git.blameInfo!,
        editorState: widget.config.state,
        size: size,
        gitService: widget.config.services.gitService,
      ),
    );
  }

  Widget _buildHoverInfoWidget() {
    return HoverInfoWidget(
      editorState: widget.config.state,
      editorLayoutService: widget.config.services.layoutService,
      editorConfigService: widget.config.services.configService,
      isHoveringWord: managers.hover.isHoveringWord,
      onHoverPopup: onHoverPopup,
      onLeavePopup: onLeavePopup,
      row: widget.config.row,
      col: widget.config.col,
      globalHoverState: widget.config.globalHoverState,
    );
  }

  Widget _buildCompletionOverlay() {
    return ListenableBuilder(
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
    );
  }

  void _handleMouseHover(PointerHoverEvent event) {
    if (_shouldSkipHoverHandling()) return;

    final cursorPosition = _calculateCursorPosition(event);
    final wordInfo = managers.hover.getWordInfoAtPosition(cursorPosition);

    if (_hasWordChanged(wordInfo)) {
      if (!managers.hover.isHoveringPopup) {
        managers.hover.handleEmptyWord();
      }
    }

    managers.hover.wordHighlightTimer?.cancel();

    if (wordInfo == null) {
      _handleEmptyWordHover();
      return;
    }

    _updateHoverState(wordInfo, event, cursorPosition);
  }

  bool _shouldSkipHoverHandling() {
    return managers.keyEvent.isTyping ||
        (managers.cursor.isCursorMovementRecent &&
            !managers.hover.isHoveringPopup);
  }

  Position _calculateCursorPosition(PointerHoverEvent event) {
    return managers.hover.getPositionFromOffset(Offset(
      event.localPosition.dx +
          widget.config.scrollConfig.horizontalController.offset,
      event.localPosition.dy +
          widget.config.scrollConfig.verticalController.offset,
    ));
  }

  bool _hasWordChanged(WordInfo? wordInfo) {
    return managers.hover.lastHoveredWord?.word != wordInfo?.word ||
        managers.hover.lastHoveredWord?.startColumn != wordInfo?.startColumn ||
        managers.hover.lastHoveredWord?.startLine != wordInfo?.startLine;
  }

  void _handleEmptyWordHover() {
    managers.hover.wordHighlightTimer =
        Timer(const Duration(milliseconds: 100), () {
      if (mounted) {
        managers.hover.handleEmptyWord();
      }
    });
  }

  void _updateHoverState(
      WordInfo wordInfo, PointerHoverEvent event, Position cursorPosition) {
    managers.hover.lastHoveredWord = wordInfo;
    setState(() {
      managers.hover.hoverPosition = event.localPosition;
    });

    managers.hover.wordHighlightTimer =
        Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      await _handleWordHoverTimer(wordInfo, cursorPosition);
    });
  }

  Future<void> _handleWordHoverTimer(
      WordInfo wordInfo, Position cursorPosition) async {
    if (!managers.hover.isHoveringWord) {
      setState(() {
        managers.hover.isHoveringWord = true;
        managers.hover.hoveredWordRange = TextRange(
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
    }

    final diagnostics = await widget.config.state.showDiagnostics(
      cursorPosition.line,
      wordInfo.startColumn,
    );

    setState(() {
      managers.hover.hoveredInfo = diagnostics;
    });

    await widget.config.state
        .showHover(cursorPosition.line, wordInfo.startColumn);
  }

  void requestFocus() {
    managers.focus.focusNode.requestFocus();
  }
}
