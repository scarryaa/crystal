import 'package:crystal/models/menu_item_data.dart';
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
        onTap: onClose,
      ),
      MenuItemData(
        icon: Icons.arrow_right,
        text: 'Close Tabs to the Right',
        onTap: onCloseTabsToRight,
      ),
      MenuItemData(
        icon: Icons.arrow_left,
        text: 'Close Tabs to the Left',
        onTap: onCloseTabsToLeft,
      ),
      MenuItemData(
        icon: Icons.close_fullscreen,
        text: 'Close Other Tabs',
        onTap: onCloseOtherTabs,
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
    if (!editor.buffer.isDirty) {
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

  Widget _buildActionButton() {
    final theme = editorConfigService.themeService.currentTheme;
    final color = isActive
        ? theme?.primary ?? Colors.blue
        : theme?.text ?? Colors.black54;

    return MouseRegion(
      child: GestureDetector(
        onTap: isPinned ? onPin : onClose,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isPinned ? onPin : onClose,
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

  @override
  Widget build(BuildContext context) {
    final theme = editorConfigService.themeService.currentTheme;

    return ListenableBuilder(
        listenable: Listenable.merge([editorConfigService, editor]),
        builder: (context, child) {
          return Semantics(
            // TODO add tab index?
            label: '${_getDisplayName()} tab',
            selected: isActive,
            button: true,
            child: InkWell(
              onTap: onTap,
              child: GestureDetector(
                onTertiaryTapDown: (_) => onClose(),
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
