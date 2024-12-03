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

  void _handleEditorCore(EditorCore core) {
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
        if (core != null) Gutter(core: core!),
        Editor(
          onCoreInitialized: _handleEditorCore,
        ),
      ],
    );
  }
}
