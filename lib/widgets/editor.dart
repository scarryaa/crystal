import 'package:crystal/state/editor_state.dart';
import 'package:crystal/widgets/editor_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Editor extends StatefulWidget {
  final EditorState state;

  const Editor({super.key, required this.state});

  @override
  State<StatefulWidget> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: CustomPaint(
        painter: EditorPainter(editorState: widget.state),
        size: const Size(double.infinity, double.infinity),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.enter:
          // Handle enter key
          return KeyEventResult.handled;
        case LogicalKeyboardKey.backspace:
          // Handle backspace
          return KeyEventResult.handled;
        case LogicalKeyboardKey.delete:
          // Handle delete
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
