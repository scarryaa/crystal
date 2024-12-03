import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/editor/editor.dart';
import 'package:crystal/widgets/gutter/gutter.dart';
import 'package:flutter/material.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  @override
  State<StatefulWidget> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  EditorCore? core;
  final ScrollController _editorVerticalScrollController = ScrollController();
  final ScrollController _editorHorizontalScrollController = ScrollController();
  final ScrollController _gutterVerticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _editorVerticalScrollController.addListener(() {
      if (_gutterVerticalScrollController.offset !=
          _editorVerticalScrollController.offset) {
        _gutterVerticalScrollController
            .jumpTo(_editorVerticalScrollController.offset);
      }
    });

    _gutterVerticalScrollController.addListener(() {
      if (_gutterVerticalScrollController.offset !=
          _editorVerticalScrollController.offset) {
        _editorVerticalScrollController
            .jumpTo(_gutterVerticalScrollController.offset);
      }
    });
  }

  @override
  void dispose() {
    _editorVerticalScrollController.dispose();
    _gutterVerticalScrollController.dispose();
    _editorHorizontalScrollController.dispose();
    super.dispose();
  }

  void _handleEditorCore(EditorCore core) {
    // Needed to prevent setState during build error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        this.core = core;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (core != null)
          Gutter(
            core: core!,
            verticalScrollController: _gutterVerticalScrollController,
          ),
        Expanded(
          child: Editor(
            onCoreInitialized: _handleEditorCore,
            verticalScrollController: _editorVerticalScrollController,
            horizontalScrollController: _editorHorizontalScrollController,
          ),
        ),
      ],
    );
  }
}
