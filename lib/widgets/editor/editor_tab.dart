import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
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

  const EditorTab({
    required this.editor,
    required this.isActive,
    required this.isPinned,
    required this.onTap,
    required this.onClose,
    required this.onPin,
    required this.editorConfigService,
    super.key,
  });

  void _showContextMenu(BuildContext context, TapDownDetails details) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final theme = editorConfigService.themeService.currentTheme;
    final textColor = theme?.text ?? Colors.black87;
    final backgroundColor = theme?.background ?? Colors.white;

    showMenu(
      context: context,
      position: position,
      color: backgroundColor.withRed(30).withBlue(30).withGreen(30),
      items: [
        _buildMenuItem(
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          text: isPinned ? 'Unpin Tab' : 'Pin Tab',
          onTap: onPin,
          textColor: textColor,
        ),
        _buildMenuItem(
          icon: Icons.close,
          text: 'Close',
          onTap: onClose,
          textColor: textColor,
        ),
      ],
    );
  }

  PopupMenuItem _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    required Color textColor,
  }) {
    return PopupMenuItem(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: _kSpacing),
          Text(
            text,
            style: TextStyle(color: textColor),
          ),
        ],
      ),
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
        listenable: editorConfigService,
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
