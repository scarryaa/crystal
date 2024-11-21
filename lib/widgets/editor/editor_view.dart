import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/models/editor/commands/editing_commands.dart';
import 'package:crystal/models/editor/commands/file_commands.dart';
import 'package:crystal/models/editor/commands/navigation_commands.dart';
import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_input_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/editor_keyboard_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/file_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/navigation_handler.dart';
import 'package:crystal/services/editor/handlers/keyboard/text_editing_handler.dart';
import 'package:crystal/services/editor/view/cursor_manager.dart';
import 'package:crystal/services/editor/view/editor_painter_manager.dart';
import 'package:crystal/services/editor/view/focus_manager.dart';
import 'package:crystal/services/editor/view/git_manager.dart';
import 'package:crystal/services/editor/view/hover_manager.dart';
import 'package:crystal/services/editor/view/key_event_manager.dart';
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
  late final CursorManager cursorManager;
  late final FocusManager focusManager;
  late final HoverManager hoverManager;
  late final GitManager gitManager;
  late final KeyEventManager keyEventManager;
  late final EditorPainterManager editorPainterManager;
  late final EditorInputHandler editorInputHandler;
  late final EditorKeyboardHandler editorKeyboardHandler;

  EditorSyntaxHighlighter? editorSyntaxHighlighter;

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
      gitManager.initializeGit();
      widget.config.services.gitService
          .setOriginalContent(widget.config.state.relativePath ?? '');
    }
  }

  @override
  void initState() {
    super.initState();

    hoverManager = HoverManager(config: widget.config);
    cursorManager = CursorManager(widget.config, hoverManager);
    focusManager = FocusManager(config: widget.config);
    gitManager = GitManager(config: widget.config);
    editorPainterManager = EditorPainterManager(config: widget.config);

    EditorEventBus.on<CursorEvent>().listen((_) {
      cursorManager.handleCursorMove();
    });

    widget.config.scrollConfig.verticalController
        .addListener(hoverManager.hidePopups);
    widget.config.scrollConfig.horizontalController
        .addListener(hoverManager.hidePopups);
    gitManager.initializeGit();

    EditorEventBus.on<TextEvent>().listen((_) {
      if (!hoverManager.isHoveringPopup) {
        setState(() {
          hoverManager.isHoveringPopup = false;
          hoverManager.isHoveringWord = false;
        });
        // Force emit a hover clear event
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
        ));
      }
    });

    focusManager.focusNode.addListener(() {
      setState(() {
        focusManager.isFocused = focusManager.focusNode.hasFocus;
        if (!focusManager.isFocused) {
          widget.config.state.showCaret = false;
          focusManager.stopCaretBlinking();
        } else {
          focusManager.startCaretBlinking();
        }
      });
    });

    editorInputHandler = EditorInputHandler(
        resetCaretBlink: focusManager.resetCaretBlink,
        requestFocus: requestFocus);

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
        updateSingleLineWidth: editorPainterManager.updateSingleLineWidth,
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
    keyEventManager = KeyEventManager(editorKeyboardHandler);

    editorPainterManager.updateCachedMaxLineWidth();
    focusManager.startCaretBlinking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      focusManager.focusNode.requestFocus();
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
    focusManager.dispose();
    cursorManager.dispose();
    hoverManager.dispose();
    hoverManager.wordHighlightTimer?.cancel();
    widget.config.scrollConfig.verticalController
        .removeListener(hoverManager.hidePopups);
    widget.config.scrollConfig.horizontalController
        .removeListener(hoverManager.hidePopups);
    focusManager.stopCaretBlinking();
    focusManager.focusNode.dispose();
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
      hoverManager.isHoveringPopup = true;
    });
  }

  void onLeavePopup() {
    if (mounted) {
      setState(() {
        hoverManager.isHoveringPopup = false;
      });
    }
  }

  void updateCachedMaxLineWidth() =>
      editorPainterManager.updateCachedMaxLineWidth();

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.max(
      mediaQuery.size.width -
          widget.config.services.layoutService.config.gutterWidth -
          (widget.config.services.configService.config.isFileExplorerVisible
              ? widget.config.services.configService.config.fileExplorerWidth
              : 0),
      editorPainterManager.cachedMaxLineWidth +
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

    editorPainterManager.editorPainter = EditorPainter(
      editorConfigService: widget.config.services.configService,
      editorLayoutService: widget.config.services.layoutService,
      editorSyntaxHighlighter: editorSyntaxHighlighter!,
      editorState: widget.config.state,
      searchTerm: widget.config.searchConfig.searchTerm,
      searchTermMatches: widget.config.searchConfig.matches,
      currentSearchTermMatch: widget.config.searchConfig.currentMatch,
      viewportHeight: MediaQuery.of(context).size.height,
      isFocused: focusManager.isFocused,
      blameInfo: gitManager.blameInfo ?? [],
      hoverPosition: hoverManager.hoverPosition,
      hoveredWordRange: hoverManager.hoveredWordRange,
      currentWordOccurrences: currentWordOccurrences,
      hoveredInfo: hoverManager.hoveredInfo,
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
                  focusNode: focusManager.focusNode,
                  onKeyEvent: (node, event) {
                    keyEventManager.handleKeyEventAsync(node, event);
                    return KeyEventResult.handled;
                  },
                  autofocus: true,
                  child: MouseRegion(
                    onEnter: (_) => widget.config.globalHoverState
                        .setActiveEditor(widget.config.row, widget.config.col),
                    onExit: (_) {
                      hoverManager.wordHighlightTimer?.cancel();

                      if (!hoverManager.isHoveringPopup) {
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (!hoverManager.isHoveringPopup && mounted) {
                            widget.config.globalHoverState.clearActiveEditor();
                          }
                        });
                      }
                    },
                    onHover: (PointerHoverEvent event) {
                      if (keyEventManager.isTyping ||
                          cursorManager.isCursorMovementRecent &&
                              (!hoverManager.isHoveringPopup)) {
                        hoverManager.handleEmptyWord();
                        return;
                      }

                      final cursorPosition =
                          hoverManager.getPositionFromOffset(Offset(
                        event.localPosition.dx +
                            widget.config.scrollConfig.horizontalController
                                .offset,
                        event.localPosition.dy +
                            widget
                                .config.scrollConfig.verticalController.offset,
                      ));

                      final wordInfo =
                          hoverManager.getWordInfoAtPosition(cursorPosition);

                      // Check if the hovered word is different from the last hovered word
                      if (hoverManager.lastHoveredWord?.word !=
                              wordInfo?.word ||
                          hoverManager.lastHoveredWord?.startColumn !=
                              wordInfo?.startColumn ||
                          hoverManager.lastHoveredWord?.startLine !=
                              wordInfo?.startLine) {
                        if (!hoverManager.isHoveringPopup) {
                          hoverManager.handleEmptyWord();
                        }
                      }

                      // Cancel any existing timers
                      hoverManager.wordHighlightTimer?.cancel();

                      // Handle the case where no word is hovered
                      if (wordInfo == null) {
                        hoverManager.wordHighlightTimer =
                            Timer(const Duration(milliseconds: 100), () {
                          if (mounted) {
                            hoverManager.handleEmptyWord();
                          }
                        });
                        return;
                      }

                      // Update the last hovered word and hover position
                      hoverManager.lastHoveredWord = wordInfo;
                      setState(() {
                        hoverManager.hoverPosition = event.localPosition;
                      });

                      // Set a new timer to handle the word highlight and diagnostics
                      hoverManager.wordHighlightTimer =
                          Timer(const Duration(milliseconds: 300), () async {
                        if (!mounted) return;

                        if (!hoverManager.isHoveringWord) {
                          setState(() {
                            hoverManager.isHoveringWord = true;
                            hoverManager.hoveredWordRange = TextRange(
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

                        // Get the diagnostics for the new word
                        final diagnostics = await widget.config.state
                            .showDiagnostics(
                                cursorPosition.line, wordInfo.startColumn);

                        // Update state with the diagnostics if still mounted
                        setState(() {
                          hoverManager.hoveredInfo = diagnostics;
                        });

                        await widget.config.state.showHover(
                            cursorPosition.line, wordInfo.startColumn);
                      });
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) {
                        hoverManager.hidePopups();
                        hoverManager.cancelHoverOperations();
                        editorInputHandler.handleTap(
                          details,
                          widget.config.scrollConfig.verticalController.offset,
                          widget
                              .config.scrollConfig.horizontalController.offset,
                          editorPainterManager.editorPainter,
                          widget.config.state,
                        );
                      },
                      onPanStart: (details) =>
                          editorInputHandler.handleDragStart(
                        details,
                        widget.config.scrollConfig.verticalController.offset,
                        widget.config.scrollConfig.horizontalController.offset,
                        editorPainterManager.editorPainter,
                        widget.config.state,
                      ),
                      onPanUpdate: (details) =>
                          editorInputHandler.handleDragUpdate(
                        details,
                        widget.config.scrollConfig.verticalController.offset,
                        widget.config.scrollConfig.horizontalController.offset,
                        editorPainterManager.editorPainter,
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
                                          painter: editorPainterManager
                                              .editorPainter,
                                          size: Size(width, height),
                                        ),
                                        if (gitManager.blameInfo != null &&
                                            gitManager.blameInfo!.isNotEmpty)
                                          Positioned.fill(
                                            child: BlameInfoWidget(
                                              editorConfigService: widget.config
                                                  .services.configService,
                                              editorLayoutService: widget.config
                                                  .services.layoutService,
                                              blameInfo: gitManager.blameInfo!,
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
                                          isHoveringWord:
                                              hoverManager.isHoveringWord,
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

  void requestFocus() {
    focusManager.focusNode.requestFocus();
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
