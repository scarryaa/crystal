import 'dart:async';
import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/editor/search_match.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorView extends StatefulWidget {
  final EditorState state;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final double gutterWidth;
  final VoidCallback scrollToCursor;
  final Function(String newTerm) onSearchTermChanged;
  final String searchTerm;
  final int currentSearchTermMatch;
  final List<SearchMatch> searchTermMatches;

  const EditorView({
    super.key,
    required this.state,
    required this.gutterWidth,
    required this.verticalScrollController,
    required this.horizontalScrollController,
    required this.scrollToCursor,
    required this.searchTerm,
    required this.searchTermMatches,
    required this.onSearchTermChanged,
    required this.currentSearchTermMatch,
  });

  @override
  State<StatefulWidget> createState() => _EditorViewState();
}

class _EditorViewState extends State<EditorView> {
  final FocusNode _focusNode = FocusNode();
  double _cachedMaxLineWidth = 0;
  Timer? _caretTimer;
  final EditorSyntaxHighlighter editorSyntaxHighlighter =
      EditorSyntaxHighlighter();

  @override
  void initState() {
    super.initState();
    _updateCachedMaxLineWidth();
    _startCaretBlinking();
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

  void _updateCachedMaxLineWidth() {
    _cachedMaxLineWidth = _maxLineWidth();
  }

  double _maxLineWidth() {
    return widget.state.buffer.lines.fold<double>(0, (maxWidth, line) {
      final lineWidth = EditorPainter.measureLineWidth(line);
      return math.max(maxWidth, lineWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.max(
      mediaQuery.size.width - widget.gutterWidth - 151, // File Explorer
      _cachedMaxLineWidth + EditorConstants.horizontalPadding,
    );
    final height = math.max(
      mediaQuery.size.height,
      EditorConstants.lineHeight * widget.state.buffer.lineCount +
          EditorConstants.verticalPadding,
    );
    widget.state.scrollState
        .updateViewportHeight(MediaQuery.of(context).size.height);

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: GestureDetector(
          onTapDown: _handleTap,
          onPanStart: _handleDragStart,
          onPanUpdate: _handleDragUpdate,
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
                  behavior: const ScrollBehavior().copyWith(scrollbars: false),
                  child: SingleChildScrollView(
                    controller: widget.verticalScrollController,
                    child: SingleChildScrollView(
                      controller: widget.horizontalScrollController,
                      scrollDirection: Axis.horizontal,
                      child: CustomPaint(
                        painter: EditorPainter(
                          editorSyntaxHighlighter: editorSyntaxHighlighter,
                          editorState: widget.state,
                          searchTerm: widget.searchTerm,
                          searchTermMatches: widget.searchTermMatches,
                          currentSearchTermMatch: widget.currentSearchTermMatch,
                          viewportHeight: MediaQuery.of(context).size.height,
                        ),
                        size: Size(width, height),
                      ),
                    ),
                  ),
                ),
              ))),
    );
  }

  void _handleTap(TapDownDetails details) {
    _focusNode.requestFocus();

    final localY =
        details.localPosition.dy + widget.verticalScrollController.offset;
    final localX =
        details.localPosition.dx + widget.horizontalScrollController.offset;
    widget.state.handleTap(localY, localX, EditorPainter.measureLineWidth);
    _resetCaretBlink();
  }

  void _handleDragStart(DragStartDetails details) {
    widget.state.handleDragStart(
        details.localPosition.dy + widget.verticalScrollController.offset,
        details.localPosition.dx + widget.horizontalScrollController.offset,
        EditorPainter.measureLineWidth);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    widget.state.handleDragUpdate(
        details.localPosition.dy + widget.verticalScrollController.offset,
        details.localPosition.dx,
        EditorPainter.measureLineWidth);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    _resetCaretBlink();

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final bool isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

      // Special keys
      if (widget.state.handleSpecialKeys(
          isControlPressed, isShiftPressed, event.logicalKey)) {
        widget.onSearchTermChanged(widget.searchTerm);
        return KeyEventResult.handled;
      }

      // Ctrl shortcuts
      switch (event.logicalKey) {
        case LogicalKeyboardKey.keyC:
          if (isControlPressed) {
            widget.state.copy();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyX:
          if (isControlPressed) {
            widget.state.cut();
            _updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.scrollToCursor();
              widget.onSearchTermChanged(widget.searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyV:
          if (isControlPressed) {
            widget.state.paste();
            _updateCachedMaxLineWidth();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              widget.scrollToCursor();
              widget.onSearchTermChanged(widget.searchTerm);
            });
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyA:
          if (isControlPressed) {
            widget.state.selectAll();
            widget.scrollToCursor();
            return KeyEventResult.handled;
          }
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          widget.state.moveCursorDown(isShiftPressed);
          widget.scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          widget.state.moveCursorUp(isShiftPressed);
          widget.scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          widget.state.moveCursorLeft(isShiftPressed);
          widget.scrollToCursor();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          widget.state.moveCursorRight(isShiftPressed);
          widget.scrollToCursor();
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          widget.state.insertNewLine();
          _updateCachedMaxLineWidth();
          widget.scrollToCursor();
          widget.onSearchTermChanged(widget.searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          widget.state.backspace();
          _updateCachedMaxLineWidth();
          widget.scrollToCursor();
          widget.onSearchTermChanged(widget.searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          widget.state.delete();
          _updateCachedMaxLineWidth();
          widget.scrollToCursor();
          widget.onSearchTermChanged(widget.searchTerm);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.tab:
          if (isShiftPressed) {
            widget.state.backTab();
          } else {
            widget.state.insertTab();
            _updateCachedMaxLineWidth();
          }
          widget.scrollToCursor();
          widget.onSearchTermChanged(widget.searchTerm);
          return KeyEventResult.handled;
        default:
          if (event.character != null &&
              event.character!.length == 1 &&
              event.logicalKey != LogicalKeyboardKey.escape) {
            widget.state.insertChar(event.character!);
            _updateCachedMaxLineWidth();
            widget.scrollToCursor();
            widget.onSearchTermChanged(widget.searchTerm);
            return KeyEventResult.handled;
          }
      }
    }

    return KeyEventResult.ignored;
  }
}
