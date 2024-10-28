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
  late EditorState _editorState;

  void tapCallback(String path) {
    _editorState.openFile(path);
  }

  @override
  void initState() {
    super.initState();
    _editorState = EditorState(resetGutterScroll: _resetGutterScroll);
    _editorVerticalScrollController.addListener(_handleEditorScroll);
    _gutterScrollController.addListener(_handleGutterScroll);
  }

  void _handleEditorScroll() {
    // Vertical offset
    if (_gutterScrollController.offset !=
        _editorVerticalScrollController.offset) {
      _gutterScrollController.jumpTo(_editorVerticalScrollController.offset);
      _editorState
          .updateVerticalScrollOffset(_editorVerticalScrollController.offset);
    }

    // Horizontal offset
    _editorState
        .updateHorizontalScrollOffset(_editorHorizontalScrollController.offset);
  }

  void _handleGutterScroll() {
    if (_editorVerticalScrollController.offset !=
        _gutterScrollController.offset) {
      _editorVerticalScrollController.jumpTo(_gutterScrollController.offset);
      _editorState.updateVerticalScrollOffset(_gutterScrollController.offset);
    }
  }

  void _resetGutterScroll() {
    _gutterScrollController.jumpTo(0);
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
      value: _editorState,
      child: Consumer<EditorState>(
        builder: (context, state, _) {
          final gutterWidth = state.getGutterWidth();

          return Row(
            children: [
              FileExplorer(
                rootDir: '',
                tapCallback: tapCallback,
              ),
              Gutter(
                editorState: state,
                verticalScrollController: _gutterScrollController,
              ),
              Expanded(
                child: Editor(
                  state: state,
                  gutterWidth: gutterWidth,
                  verticalScrollController: _editorVerticalScrollController,
                  horizontalScrollController: _editorHorizontalScrollController,
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
