import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Editor extends StatefulWidget {
  final EditorState state;
  final ScrollController verticalScrollController;
  final ScrollController horizontalScrollController;
  final double gutterWidth;

  const Editor(
      {super.key,
      required this.state,
      required this.gutterWidth,
      required this.verticalScrollController,
      required this.horizontalScrollController});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final FocusNode _focusNode = FocusNode();
  double _cachedMaxLineWidth = 0;

  @override
  void initState() {
    _updateCachedMaxLineWidth();
    super.initState();
  }

  void _updateCachedMaxLineWidth() {
    _cachedMaxLineWidth = _maxLineWidth();
  }

  double _maxLineWidth() {
    return widget.state.lines.fold<double>(0, (maxWidth, line) {
      final lineWidth = EditorPainter.measureLineWidth(line);
      return math.max(maxWidth, lineWidth);
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = math.max(
      mediaQuery.size.width - widget.gutterWidth,
      _cachedMaxLineWidth + EditorConstants.horizontalPadding,
    );
    final height = math.max(
      mediaQuery.size.height,
      EditorConstants.lineHeight * widget.state.lines.length +
          EditorConstants.verticalPadding,
    );

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
                          editorState: widget.state,
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
    widget.state.handleTap(details.globalPosition.dy, details.localPosition.dx,
        EditorPainter.measureLineWidth);
  }

  void _handleDragStart(DragStartDetails details) {
    widget.state.handleDragStart(details.globalPosition.dy,
        details.localPosition.dx, EditorPainter.measureLineWidth);
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    widget.state.handleDragUpdate(details.globalPosition.dy,
        details.localPosition.dx, EditorPainter.measureLineWidth);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final bool isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

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
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyV:
          if (isControlPressed) {
            widget.state.paste();
            _updateCachedMaxLineWidth();
            return KeyEventResult.handled;
          }
        case LogicalKeyboardKey.keyA:
          if (isControlPressed) {
            widget.state.selectAll();
            return KeyEventResult.handled;
          }
      }

      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowDown:
          widget.state.moveCursorDown(isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          widget.state.moveCursorUp(isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowLeft:
          widget.state.moveCursorLeft(isShiftPressed);
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          widget.state.moveCursorRight(isShiftPressed);
          return KeyEventResult.handled;

        case LogicalKeyboardKey.enter:
          widget.state.insertNewLine();
          _updateCachedMaxLineWidth();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          widget.state.backspace();
          _updateCachedMaxLineWidth();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          widget.state.delete();
          _updateCachedMaxLineWidth();
          return KeyEventResult.handled;
        default:
          if (event.character != null) {
            widget.state.insertChar(event.character!);
            _updateCachedMaxLineWidth();
            return KeyEventResult.handled;
          }
      }
    }

    return KeyEventResult.ignored;
  }
}
