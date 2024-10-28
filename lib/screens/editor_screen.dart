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
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EditorState(),
      child: Row(
        children: [
          const Gutter(),
          Expanded(
            child: Consumer<EditorState>(
              builder: (context, state, _) => Editor(
                state: state,
              ),
            ),
          )
        ],
      ),
    );
  }
}
