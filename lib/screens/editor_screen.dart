import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor.dart';
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
  final ScrollController _editorScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _editorScrollController.addListener(() {
      _gutterScrollController.jumpTo(_editorScrollController.offset);
    });
    _gutterScrollController.addListener(() {
      _editorScrollController.jumpTo(_gutterScrollController.offset);
    });
  }

  @override
  void dispose() {
    _gutterScrollController.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorState(),
      child: Consumer<EditorState>(
        builder: (context, state, _) {
          final gutterWidth = state.getGutterWidth();

          return Row(
            children: [
              Gutter(
                editorState: state,
                verticalScrollController: _gutterScrollController,
              ),
              Expanded(
                child: Editor(
                  gutterWidth: gutterWidth,
                  state: state,
                  verticalScrollController: _editorScrollController,
                ),
              )
            ],
          );
        },
      ),
    );
  }
}
