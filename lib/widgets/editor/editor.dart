import 'dart:math' as math;

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Editor extends StatefulWidget {
  final EditorState state;
  final ScrollController? verticalScrollController;
  final double gutterWidth;

  const Editor({
    super.key,
    required this.state,
    required this.gutterWidth,
    this.verticalScrollController,
  });

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final FocusNode _focusNode = FocusNode();
  final ScrollController _horizontalScrollController = ScrollController();

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
          controller: _horizontalScrollController,
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
      switch (event.logicalKey) {
        // Arrow keys
        case LogicalKeyboardKey.arrowDown:
          widget.state.moveCursorDown();
        case LogicalKeyboardKey.arrowUp:
          widget.state.moveCursorUp();
        case LogicalKeyboardKey.arrowLeft:
          widget.state.moveCursorLeft();
        case LogicalKeyboardKey.arrowRight:
          widget.state.moveCursorRight();

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