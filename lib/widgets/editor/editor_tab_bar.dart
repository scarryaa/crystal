import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
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
  final Function() onSplitClose;
  final EditorConfigService editorConfigService;
  final EditorTabManager editorTabManager;
  final int row;
  final int col;
  final GlobalKey tabScrollKey;
  final FileService fileService;
  final Function(String)? onDirectoryChanged;
  final ScrollController tabBarScrollController;

  const EditorTabBar({
    super.key,
    required this.tabScrollKey,
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
    required this.editorTabManager,
    required this.row,
    required this.col,
    required this.tabBarScrollController,
    required this.fileService,
    required this.onDirectoryChanged,
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
        fileService: widget.fileService,
        onDirectoryChanged: widget.onDirectoryChanged,
      );

      newEditor.openFile(activeEditor.buffer.content);
      widget.onSplitVertical();
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
        fileService: widget.fileService,
        onDirectoryChanged: widget.onDirectoryChanged,
      );

      newEditor.openFile(activeEditor.buffer.content);
      widget.onSplitHorizontal();
      widget.onActiveEditorChanged(widget.activeEditorIndex);
    }
  }

  void _handleEditorClosed(int index) {
    widget.onEditorClosed(index);
  }

  Widget _buildSplitButtons() {
    // Only show split controls if this is the active split view
    if (widget.row != widget.editorTabManager.activeRow ||
        widget.col != widget.editorTabManager.activeCol) {
      return const SizedBox.shrink();
    }

    final theme = widget.editorConfigService.themeService.currentTheme;
    final iconColor = theme?.text ?? Colors.black;

    return Row(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      key: widget.tabScrollKey,
      listenable: widget.editorConfigService,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: widget
                    .editorConfigService.themeService.currentTheme?.background
                    .withRed(30)
                    .withBlue(30)
                    .withGreen(30) ??
                Colors.white,
          ),
          height: widget.editorConfigService.config.uiFontSize * 2.5,
          child: Row(
            children: [
              Expanded(
                child: ReorderableListView.builder(
                  scrollController: widget.tabBarScrollController,
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
