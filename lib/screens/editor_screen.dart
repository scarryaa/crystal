import 'dart:io';
import 'dart:math';
import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor.dart';
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
    final currentLine = activeEditor!.lines[cursorLine];
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
                      Container(
                        color: Colors.grey[200],
                        height: 35,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _editors.length,
                          itemBuilder: (context, index) {
                            final editor = _editors[index];
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  activeEditorIndex = index;
                                });
                              },
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: index == activeEditorIndex
                                          ? Colors.blue
                                          : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      editor.path.split('/').last,
                                      style: TextStyle(
                                        color: index == activeEditorIndex
                                            ? Colors.blue
                                            : Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        setState(() {
                                          _editors.removeAt(index);
                                          if (activeEditorIndex >=
                                              _editors.length) {
                                            activeEditorIndex =
                                                _editors.length - 1;
                                          }
                                        });
                                      },
                                      child: Icon(
                                        Icons.close,
                                        size: 16,
                                        color: index == activeEditorIndex
                                            ? Colors.blue
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    Expanded(
                      child: Row(
                        children: [
                          if (_editors.isNotEmpty)
                            Gutter(
                              editorState: state!,
                              verticalScrollController: _gutterScrollController,
                            ),
                          Expanded(
                            child: _editors.isNotEmpty
                                ? Editor(
                                    state: state!,
                                    scrollToCursor: _scrollToCursor,
                                    gutterWidth: gutterWidth!,
                                    verticalScrollController:
                                        _editorVerticalScrollController,
                                    horizontalScrollController:
                                        _editorHorizontalScrollController,
                                  )
                                : Container(color: Colors.white),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ));
        },
      ),
    );
  }
}
