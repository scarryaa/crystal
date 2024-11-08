import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/editor_tab.dart';
import 'package:flutter/material.dart';

class EditorTabBar extends StatefulWidget {
  final List<EditorState> editors;
  final int activeEditorIndex;
  final Function(int) onActiveEditorChanged;
  final Function(int) onEditorClosed;
  final Function(int, int) onReorder;
  final Function(int) onPin;
  final EditorConfigService editorConfigService;

  const EditorTabBar({
    super.key,
    required this.editors,
    required this.activeEditorIndex,
    required this.onActiveEditorChanged,
    required this.onEditorClosed,
    required this.onReorder,
    required this.onPin,
    required this.editorConfigService,
  });

  @override
  State<EditorTabBar> createState() => _EditorTabBarState();
}

class _EditorTabBarState extends State<EditorTabBar> {
  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: widget.editorConfigService.themeService.currentTheme != null
              ? widget.editorConfigService.themeService.currentTheme!.background
              : Colors.white,
        ),
        height: 35,
        child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            onReorder: widget.onReorder,
            itemCount: widget.editors.length,
            itemBuilder: (context, index) {
              final editor = widget.editors[index];
              return ReorderableDragStartListener(
                key: ValueKey(editor.id),
                index: index,
                child: EditorTab(
                  editorConfigService: widget.editorConfigService,
                  editor: editor,
                  isActive: index == widget.activeEditorIndex,
                  onTap: () => widget.onActiveEditorChanged(index),
                  onClose: () => widget.onEditorClosed(index),
                  onPin: () => widget.onPin(index),
                  isPinned: editor.isPinned,
                ),
              );
            }));
  }
}
