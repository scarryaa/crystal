import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTab extends StatelessWidget {
  final EditorState editor;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final EditorConfigService editorConfigService;

  const EditorTab({
    required this.editor,
    required this.isActive,
    required this.onTap,
    required this.onClose,
    required this.editorConfigService,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        child: GestureDetector(
          onTertiaryTapDown: (_) => onClose(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: editorConfigService.themeService.currentTheme != null
                      ? editorConfigService.themeService.currentTheme!.border
                      : Colors.grey[200]!,
                ),
                bottom: BorderSide(
                  color: isActive
                      ? Colors.transparent
                      : editorConfigService.themeService.currentTheme != null
                          ? editorConfigService
                              .themeService.currentTheme!.border
                          : Colors.grey[200]!,
                ),
              ),
              color: isActive
                  ? editorConfigService.themeService.currentTheme != null
                      ? editorConfigService
                          .themeService.currentTheme!.background
                      : Colors.white
                  : editorConfigService.themeService.currentTheme != null
                      ? editorConfigService
                          .themeService.currentTheme!.backgroundLight
                      : Colors.grey[50],
            ),
            child: Row(
              children: [
                if (editor.buffer.isDirty) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? editorConfigService.themeService.currentTheme !=
                                  null
                              ? editorConfigService
                                  .themeService.currentTheme!.primary
                              : Colors.blue
                          : editorConfigService.themeService.currentTheme !=
                                  null
                              ? editorConfigService
                                  .themeService.currentTheme!.text
                              : Colors.black54,
                    ),
                  ),
                ] else
                  const SizedBox(width: 8, height: 8),
                const SizedBox(width: 8),
                Text(
                  editor.path.split('/').last,
                  style: TextStyle(
                    color: isActive
                        ? editorConfigService.themeService.currentTheme != null
                            ? editorConfigService
                                .themeService.currentTheme!.primary
                            : Colors.blue
                        : editorConfigService.themeService.currentTheme != null
                            ? editorConfigService
                                .themeService.currentTheme!.text
                            : Colors.black87,
                  ),
                ),
                MouseRegion(
                  child: GestureDetector(
                    onTap: onClose,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onClose,
                          hoverColor:
                              editorConfigService.themeService.currentTheme !=
                                      null
                                  ? editorConfigService.themeService
                                      .currentTheme!.backgroundLight
                                  : Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close,
                              size: 16,
                              color: isActive
                                  ? editorConfigService
                                              .themeService.currentTheme !=
                                          null
                                      ? editorConfigService
                                          .themeService.currentTheme!.primary
                                      : Colors.blue
                                  : editorConfigService
                                              .themeService.currentTheme !=
                                          null
                                      ? editorConfigService
                                          .themeService.currentTheme!.text
                                      : Colors.black54,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
  }
}
