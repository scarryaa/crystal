import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatusBar extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final VoidCallback? onFileExplorerToggle;
  final VoidCallback onTerminalToggle;
  final bool? isFileExplorerVisible;

  const StatusBar({
    super.key,
    required this.editorConfigService,
    this.onFileExplorerToggle,
    required this.onTerminalToggle,
    this.isFileExplorerVisible,
  });

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  bool? _cachedFileExplorerVisible;

  @override
  void initState() {
    super.initState();
    _cachedFileExplorerVisible =
        widget.editorConfigService.config.isFileExplorerVisible;
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    if (!widget.editorConfigService.isLoaded) {
      await widget.editorConfigService.loadConfig();
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _handleFileExplorerToggle() {
    if (widget.onFileExplorerToggle != null) {
      widget.onFileExplorerToggle!();

      final newState = !(_cachedFileExplorerVisible ?? true);
      widget.editorConfigService.config.isFileExplorerVisible = newState;
      widget.editorConfigService.saveConfig();

      setState(() {
        _cachedFileExplorerVisible = newState;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: widget.editorConfigService,
        builder: (context, child) {
          if (!widget.editorConfigService.isLoaded) {
            return Container(
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          final themeColor =
              widget.editorConfigService.themeService.currentTheme?.text ??
                  Colors.black87;
          final primary =
              widget.editorConfigService.themeService.currentTheme?.primary ??
                  Colors.blue;

          return Container(
            height: widget.editorConfigService.config.uiFontSize * 1.8,
            decoration: BoxDecoration(
              color:
                  widget.editorConfigService.themeService.currentTheme != null
                      ? widget.editorConfigService.themeService.currentTheme!
                          .background
                      : Colors.white,
              border: Border.all(
                  color: widget.editorConfigService.themeService.currentTheme !=
                          null
                      ? widget
                          .editorConfigService.themeService.currentTheme!.border
                      : Colors.grey[300]!),
            ),
            child: Row(
              children: [
                MouseRegion(
                  child: GestureDetector(
                    onTap: _handleFileExplorerToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            widget.editorConfigService.config
                                    .isFileExplorerVisible
                                ? Icons.folder
                                : Icons.folder_open,
                            size: widget.editorConfigService.config.uiFontSize,
                            color: widget.editorConfigService.config
                                    .isFileExplorerVisible
                                ? primary
                                : themeColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ),
                ),
                MouseRegion(
                  child: GestureDetector(
                    onTap: widget.onTerminalToggle,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            widget.editorConfigService.config.isTerminalVisible
                                ? Icons.terminal
                                : Icons.terminal_outlined,
                            size: widget.editorConfigService.config.uiFontSize,
                            color: widget.editorConfigService.config
                                    .isTerminalVisible
                                ? primary
                                : themeColor,
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
                          fontSize:
                              widget.editorConfigService.config.uiFontSize,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        });
  }
}
