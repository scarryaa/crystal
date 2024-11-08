import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatusBar extends StatefulWidget {
  EditorConfigService editorConfigService;
  final VoidCallback? onFileExplorerToggle;
  final bool isFileExplorerVisible;

  StatusBar({
    super.key,
    required this.editorConfigService,
    this.onFileExplorerToggle,
    this.isFileExplorerVisible = true,
  });

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  @override
  Widget build(BuildContext context) {
    final themeColor =
        widget.editorConfigService.themeService.currentTheme?.text ??
            Colors.black87;

    return Container(
      height: 25,
      decoration: BoxDecoration(
        color: widget.editorConfigService.themeService.currentTheme != null
            ? widget.editorConfigService.themeService.currentTheme!.background
            : Colors.white,
        border: Border.all(
            color: widget.editorConfigService.themeService.currentTheme != null
                ? widget.editorConfigService.themeService.currentTheme!.border
                : Colors.grey[300]!),
      ),
      child: Row(
        children: [
          MouseRegion(
            child: GestureDetector(
              onTap: widget.onFileExplorerToggle,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Icon(
                      widget.isFileExplorerVisible
                          ? Icons.folder_open
                          : Icons.folder,
                      size: 16,
                      color: themeColor,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
          const Spacer(),
          Consumer<EditorState?>(
            builder: (context, state, child) {
              if (state == null) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  state.editorCursorManager.cursors.length > 1
                      ? '${state.editorCursorManager.cursors.length} cursors'
                      : '${state.editorCursorManager.cursors.first.line + 1}:${state.editorCursorManager.cursors.first.column + 1}',
                  style: TextStyle(
                    color: themeColor,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
