import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
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
  final Function() onNewTab;
  final VoidCallback onSplitHorizontal;
  final VoidCallback onSplitVertical;
  final Function(int) onSplitClose;
  final EditorConfigService editorConfigService;
  final int splitViewIndex;

  const EditorTabBar({
    super.key,
    required this.editors,
    required this.activeEditorIndex,
    required this.onActiveEditorChanged,
    required this.onEditorClosed,
    required this.onReorder,
    required this.onPin,
    required this.onSplitHorizontal,
    required this.onSplitVertical,
    required this.onNewTab,
    required this.onSplitClose,
    required this.editorConfigService,
    required this.splitViewIndex,
  });

  @override
  State<EditorTabBar> createState() => _EditorTabBarState();
}

class _EditorTabBarState extends State<EditorTabBar> {
  void _handleSplitVertical() {
    if (widget.activeEditorIndex >= 0) {
      // Get current active editor
      final activeEditor = widget.editors[widget.activeEditorIndex];

      // Create a new editor with the same state
      final newEditor = EditorState(
        editorConfigService: widget.editorConfigService,
        editorLayoutService: EditorLayoutService.instance,
        path: activeEditor.path,
        relativePath: activeEditor.relativePath,
        tapCallback: activeEditor.tapCallback,
        resetGutterScroll: activeEditor.resetGutterScroll,
      );

      // Copy the content
      newEditor.openFile(activeEditor.buffer.content);

      // Call split with the new editor
      widget.onSplitVertical();

      // Open the copied editor in the new split
      widget.onActiveEditorChanged(widget.activeEditorIndex);
    }
  }

  void _handleSplitHorizontal() {
    if (widget.activeEditorIndex >= 0) {
      // Get current active editor
      final activeEditor = widget.editors[widget.activeEditorIndex];

      // Create a new editor with the same state
      final newEditor = EditorState(
        editorConfigService: widget.editorConfigService,
        editorLayoutService: EditorLayoutService.instance,
        path: activeEditor.path,
        relativePath: activeEditor.relativePath,
        tapCallback: activeEditor.tapCallback,
        resetGutterScroll: activeEditor.resetGutterScroll,
      );

      // Copy the content
      newEditor.openFile(activeEditor.buffer.content);

      // Call split with the new editor
      widget.onSplitHorizontal();

      // Open the copied editor in the new split
      widget.onActiveEditorChanged(widget.activeEditorIndex);
    }
  }

  void _handleEditorClosed(int index) {
    widget.onEditorClosed(index);

    // Close split if no more tabs
    if (widget.editors.length <= 1 && widget.splitViewIndex > 0) {
      widget.onSplitClose(widget.splitViewIndex);
    }
  }

  Widget _buildSplitButtons() {
    final theme = widget.editorConfigService.themeService.currentTheme;
    final iconColor = theme?.text ?? Colors.black;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme?.border ?? Colors.grey,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            iconSize: widget.editorConfigService.config.uiFontSize * 1.2,
            color: iconColor,
            tooltip: 'New Tab',
            onPressed: widget.onNewTab,
          ),
          IconButton(
            icon: const Icon(Icons.splitscreen),
            iconSize: widget.editorConfigService.config.uiFontSize * 1.2,
            color: iconColor,
            tooltip: 'Split Horizontally',
            onPressed: _handleSplitHorizontal,
          ),
          IconButton(
            icon: const Icon(Icons.vertical_split),
            iconSize: widget.editorConfigService.config.uiFontSize * 1.2,
            color: iconColor,
            tooltip: 'Split Vertically',
            onPressed: _handleSplitVertical,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.editorConfigService,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget.editorConfigService.themeService.currentTheme
                    ?.background ??
                Colors.white,
          ),
          height: widget.editorConfigService.config.uiFontSize * 2.5,
          child: Row(
            children: [
              Expanded(
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
                        onClose: () => _handleEditorClosed(index),
                        onPin: () => widget.onPin(index),
                        isPinned: editor.isPinned,
                      ),
                    );
                  },
                ),
              ),
              _buildSplitButtons(),
            ],
          ),
        );
      },
    );
  }
}
