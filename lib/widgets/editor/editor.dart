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
      _maxLineWidth() + EditorConstants.horizontalPadding,
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
      child: SingleChildScrollView(
        controller: widget.verticalScrollController,
        child: SingleChildScrollView(
          controller: widget.horizontalScrollController,
          scrollDirection: Axis.horizontal,
          child: CustomPaint(
            painter: EditorPainter(editorState: widget.state),
            size: Size(width, height),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final bool isShiftPressed = HardwareKeyboard.instance.isShiftPressed;
      final bool isControlPressed =
          HardwareKeyboard.instance.isControlPressed ||
              HardwareKeyboard.instance.isMetaPressed;

      // Ctrl shortcuts
      switch (event.logicalKey) {
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
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          widget.state.backspace();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          widget.state.delete();
          return KeyEventResult.handled;
        default:
          if (event.character != null) {
            widget.state.insertChar(event.character!);
            return KeyEventResult.handled;
          }
      }
    }
    return KeyEventResult.ignored;
  }
}
