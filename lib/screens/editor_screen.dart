import 'dart:io';
import 'dart:math';

import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_control_bar_view.dart';
import 'package:crystal/widgets/editor/editor_tab_bar.dart';
import 'package:crystal/widgets/editor/editor_view.dart';
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final ScrollController _gutterScrollController = ScrollController();
  final ScrollController _editorVerticalScrollController = ScrollController();
  final ScrollController _editorHorizontalScrollController = ScrollController();
  final List<EditorState> _editors = [];

  int activeEditorIndex = 0;
  EditorState? get activeEditor =>
      _editors.isEmpty ? null : _editors[activeEditorIndex];

  Future<void> tapCallback(String path) async {
    final editorIndex = _editors.indexWhere((editor) => editor.path == path);
    if (editorIndex != -1) {
      setState(() {
        activeEditorIndex = editorIndex;
      });
    } else {
      String content = await File(path).readAsString();

      final newEditor =
          EditorState(resetGutterScroll: _resetGutterScroll, path: path);
      setState(() {
        _editors.add(newEditor);
        activeEditorIndex = _editors.length - 1;

        _editors[activeEditorIndex].openFile(content);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _editorVerticalScrollController.addListener(_handleEditorScroll);
    _gutterScrollController.addListener(_handleGutterScroll);
  }

  void _handleEditorScroll() {
    if (_gutterScrollController.offset !=
        _editorVerticalScrollController.offset) {
      _gutterScrollController.jumpTo(_editorVerticalScrollController.offset);
      activeEditor!
          .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    }

    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (_editorVerticalScrollController.offset !=
        _gutterScrollController.offset) {
      _editorVerticalScrollController.jumpTo(_gutterScrollController.offset);
      activeEditor!.updateVerticalScrollOffset(_gutterScrollController.offset);
    }
  }

  void _scrollToCursor() {
    final cursorLine = activeEditor!.cursor.line;
    final lineHeight = EditorConstants.lineHeight;
    final viewportHeight =
        _editorVerticalScrollController.position.viewportDimension;
    final currentOffset = _editorVerticalScrollController.offset;
    final verticalPadding = EditorConstants.verticalPadding;

    final cursorY = cursorLine * lineHeight;
    if (cursorY < currentOffset + verticalPadding) {
      _editorVerticalScrollController.jumpTo(max(0, cursorY - verticalPadding));
    } else if (cursorY + lineHeight >
        currentOffset + viewportHeight - verticalPadding) {
      _editorVerticalScrollController
          .jumpTo(cursorY + lineHeight - viewportHeight + verticalPadding);
    }

    final cursorColumn = activeEditor!.cursor.column;
    final currentLine = activeEditor!.buffer.getLine(cursorLine);
    final textBeforeCursor = currentLine.substring(0, cursorColumn);
    final cursorX = textBeforeCursor.length * EditorConstants.charWidth;
    final viewportWidth =
        _editorHorizontalScrollController.position.viewportDimension;
    final currentHorizontalOffset = _editorHorizontalScrollController.offset;
    const horizontalPadding = EditorConstants.horizontalPadding;

    if (cursorX < currentHorizontalOffset + horizontalPadding) {
      _editorHorizontalScrollController
          .jumpTo(max(0, cursorX - horizontalPadding));
    } else if (cursorX + EditorConstants.charWidth >
        currentHorizontalOffset + viewportWidth - horizontalPadding) {
      _editorHorizontalScrollController.jumpTo(cursorX +
          EditorConstants.charWidth -
          viewportWidth +
          horizontalPadding);
    }

    activeEditor!
        .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    activeEditor!
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _resetGutterScroll() {
    if (_gutterScrollController.hasClients) _gutterScrollController.jumpTo(0);
  }

  void onActiveEditorChanged(int index) {
    setState(() {
      activeEditorIndex = index;
      _editorVerticalScrollController
          .jumpTo(activeEditor!.scrollState.verticalOffset);
      _editorHorizontalScrollController
          .jumpTo(activeEditor!.scrollState.horizontalOffset);
    });
  }

  void onEditorClosed(int index) {
    setState(() {
      _editors.removeAt(index);
      if (activeEditorIndex >= _editors.length) {
        activeEditorIndex = _editors.length - 1;
      }
    });
  }

  void onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _editors.removeAt(oldIndex);
      _editors.insert(newIndex, item);

      if (activeEditorIndex == oldIndex) {
        activeEditorIndex = newIndex;
      } else if (activeEditorIndex > oldIndex &&
          activeEditorIndex <= newIndex) {
        activeEditorIndex--;
      } else if (activeEditorIndex < oldIndex &&
          activeEditorIndex >= newIndex) {
        activeEditorIndex++;
      }
    });
  }

  @override
  void dispose() {
    _gutterScrollController.removeListener(_handleEditorScroll);
    _gutterScrollController.removeListener(_handleGutterScroll);
    _gutterScrollController.dispose();
    _editorVerticalScrollController.dispose();
    _editorHorizontalScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: activeEditor,
      child: Consumer<EditorState?>(
        builder: (context, state, _) {
          final gutterWidth = state?.getGutterWidth();

          return Material(
              child: Row(
            children: [
              FileExplorer(
                rootDir: '',
                tapCallback: tapCallback,
              ),
              Expanded(
                child: Column(
                  children: [
                    if (_editors.isNotEmpty)
                      EditorTabBar(
                          editors: _editors,
                          activeEditorIndex: activeEditorIndex,
                          onActiveEditorChanged: onActiveEditorChanged,
                          onEditorClosed: onEditorClosed,
                          onReorder: onReorder),
                    if (_editors.isNotEmpty)
                      EditorControlBarView(filePath: activeEditor!.path),
                    _buildEditor(state, gutterWidth),
                  ],
                ),
              ),
            ],
          ));
        },
      ),
    );
  }

  Widget _buildEditor(dynamic state, double? gutterWidth) {
    return Expanded(
      child: Row(
        children: [
          if (_editors.isNotEmpty)
            Gutter(
              editorState: state!,
              verticalScrollController: _gutterScrollController,
            ),
          Expanded(
            child: _editors.isNotEmpty
                ? EditorView(
                    state: state!,
                    scrollToCursor: _scrollToCursor,
                    gutterWidth: gutterWidth!,
                    verticalScrollController: _editorVerticalScrollController,
                    horizontalScrollController:
                        _editorHorizontalScrollController,
                  )
                : Container(color: Colors.white),
          )
        ],
      ),
    );
  }
}
