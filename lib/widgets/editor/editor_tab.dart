import 'package:crystal/models/menu_item_data.dart';
import 'package:crystal/services/dialog_service.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/context_menu.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

class EditorTab extends StatelessWidget {
  static const double _kSpacing = 8.0;
  static const double _kHorizontalPadding = 16.0;

  final EditorState editor;
  final bool isActive;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final VoidCallback onPin;
  final EditorConfigService editorConfigService;
  final VoidCallback onCloseTabsToRight;
  final VoidCallback onCloseTabsToLeft;
  final VoidCallback onCloseOtherTabs;
  final List<EditorState> editors;
  final bool isDirty;

  const EditorTab({
    required this.editor,
    required this.isActive,
    required this.isPinned,
    required this.onTap,
    required this.onClose,
    required this.onPin,
    required this.editorConfigService,
    required this.onCloseTabsToRight,
    required this.onCloseTabsToLeft,
    required this.onCloseOtherTabs,
    required this.editors,
    required this.isDirty,
    super.key,
  });

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final theme = editorConfigService.themeService.currentTheme;
    final isMacOS = Theme.of(context).platform == TargetPlatform.macOS;
    final isLinux = Theme.of(context).platform == TargetPlatform.linux;

    final menuItems = [
      MenuItemData(
        icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
        text: isPinned ? 'Unpin Tab' : 'Pin Tab',
        shortcut: '',
        onTap: onPin,
        showDivider: true,
      ),
      MenuItemData(
        icon: Icons.close,
        text: 'Close',
        shortcut: isMacOS
            ? '⌘W'
            : isLinux
                ? 'Ctrl+W'
                : 'Ctrl+W',
        onTap: () => _handleClose(),
      ),
      MenuItemData(
        icon: Icons.arrow_right,
        text: 'Close Tabs to the Right',
        onTap: () => _handleCloseTabsToRight(),
      ),
      MenuItemData(
        icon: Icons.arrow_left,
        text: 'Close Tabs to the Left',
        onTap: () => _handleCloseTabsToLeft(),
      ),
      MenuItemData(
        icon: Icons.close_fullscreen,
        text: 'Close Other Tabs',
        onTap: () => _handleCloseOtherTabs(),
      ),
    ];

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (BuildContext context) {
        return ContextMenu(
          menuItems: menuItems,
          textColor: theme?.text ?? Colors.black87,
          backgroundColor: theme?.background ?? Colors.white,
          hoverColor: theme?.backgroundLight ?? Colors.black12,
          dividerColor: theme?.border ?? Colors.grey[300]!,
          position: position,
        );
      },
    );
  }

  Widget _buildStatusIndicator() {
    if (!isDirty) {
      return SizedBox(
          width: editorConfigService.config.uiFontSize / 2,
          height: editorConfigService.config.uiFontSize / 2);
    }

    final theme = editorConfigService.themeService.currentTheme;
    final color = isActive
        ? theme?.primary ?? Colors.blue
        : theme?.text ?? Colors.black54;

    return Container(
      width: editorConfigService.config.uiFontSize / 2,
      height: editorConfigService.config.uiFontSize / 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }

  Future<void> _handleClose() async {
    if (isDirty) {
      final response = await DialogService().showSavePrompt();
      switch (response) {
        case 'Save & Exit':
          await editor.save();
          onClose();
          break;
        case 'Exit without Saving':
          onClose();
          break;
        case 'Cancel':
        default:
          // Do nothing, continue editing
          break;
      }
    } else {
      onClose();
    }
  }

  Widget _buildActionButton() {
    final theme = editorConfigService.themeService.currentTheme;
    final color = isActive
        ? theme?.primary ?? Colors.blue
        : theme?.text ?? Colors.black54;

    return MouseRegion(
      child: GestureDetector(
        onTap: isPinned ? onPin : () => _handleClose(),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isPinned ? onPin : () => _handleClose(),
              hoverColor: theme?.backgroundLight ?? Colors.black12,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  isPinned ? Icons.push_pin : Icons.close,
                  size: editorConfigService.config.uiFontSize,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _getDisplayName() {
    if (editor.path.isEmpty || editor.path.substring(0, 6) == '__temp') {
      return 'untitled';
    }
    return p.basename(editor.path);
  }

  Future<void> _handleCloseTabsToRight() async {
    final parentEditors = editors;
    final currentIndex = parentEditors.indexOf(editor);

    final tabsToRight = currentIndex < 0
        ? <EditorState>[]
        : parentEditors.sublist(currentIndex + 1).cast<EditorState>();

    final success = await _handleMultipleTabsSave(tabsToRight);
    if (success) {
      onCloseTabsToRight();
    }
  }

  Future<void> _handleCloseTabsToLeft() async {
    final parentEditors = editors;
    final currentIndex = parentEditors.indexOf(editor);

    final tabsToLeft = currentIndex <= 0
        ? <EditorState>[]
        : parentEditors.sublist(0, currentIndex).cast<EditorState>();

    final success = await _handleMultipleTabsSave(tabsToLeft);
    if (success) {
      onCloseTabsToLeft();
    }
  }

  Future<void> _handleCloseOtherTabs() async {
    final parentEditors = editors;
    final currentIndex = parentEditors.indexOf(editor);

    final otherTabs = <EditorState>[
      ...parentEditors.sublist(0, currentIndex).cast<EditorState>(),
      ...parentEditors.sublist(currentIndex + 1).cast<EditorState>()
    ];

    final success = await _handleMultipleTabsSave(otherTabs);
    if (success) {
      onCloseOtherTabs();
    }
  }

  Future<bool> _handleMultipleTabsSave(List<EditorState> editors) async {
    // Filter to only get dirty editors
    final dirtyEditors = editors.where((e) => e.buffer.isDirty).toList();

    if (dirtyEditors.isEmpty) {
      return true;
    }

    // Show prompt with multiple files message
    final response = await DialogService().showMultipleFilesPrompt(
        message:
            'You have ${dirtyEditors.length} unsaved files. What would you like to do?',
        options: ['Save All', 'Save None', 'Cancel']);

    switch (response) {
      case 'Save All':
        try {
          // Attempt to save all dirty editors
          for (final editor in dirtyEditors) {
            await editor.save();
          }
          return true;
        } catch (e) {
          // Handle save error
          return false;
        }

      case 'Save None':
        // Proceed without saving any files
        return true;

      case 'Cancel':
      default:
        // User cancelled or unknown response
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = editorConfigService.themeService.currentTheme;

    return ListenableBuilder(
        listenable:
            Listenable.merge([editorConfigService, editor, editor.buffer]),
        builder: (context, child) {
          return Semantics(
            // TODO add tab index?
            label: '${_getDisplayName()} tab',
            selected: isActive,
            button: true,
            child: InkWell(
              onTap: onTap,
              child: GestureDetector(
                onTertiaryTapDown: (_) => _handleClose(),
                onSecondaryTapDown: (details) =>
                    _showContextMenu(context, details),
                child: Container(
                  height: editorConfigService.config.uiFontSize * 2.5,
                  padding: const EdgeInsets.symmetric(
                      horizontal: _kHorizontalPadding),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: theme?.border ?? Colors.grey[200]!,
                      ),
                    ),
                    color: isActive
                        ? theme?.background ?? Colors.white
                        : theme?.backgroundLight ?? Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildStatusIndicator(),
                      const SizedBox(width: _kSpacing),
                      Flexible(
                        child: Text(
                          _getDisplayName(),
                          style: TextStyle(
                            color: isActive
                                ? theme?.primary ?? Colors.blue
                                : theme?.text ?? Colors.black87,
                            fontSize: editorConfigService.config.uiFontSize,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: _kSpacing),
                      _buildActionButton(),
                    ],
                  ),
                ),
              ),
            ),
          );
        });
  }
}
