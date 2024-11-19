import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  Widget _buildLSPStatus(BuildContext context,
      EditorConfigService editorConfigService, Color themeColor) {
    return Consumer<EditorStateProvider>(
      builder: (context, editorStateProvider, _) {
        return ListenableBuilder(
          listenable: editorStateProvider.editorTabManager,
          builder: (context, _) {
            final activeEditor =
                editorStateProvider.editorTabManager.activeEditor;
            final lspService = activeEditor?.lspService;

            if (activeEditor == null || lspService == null) {
              return const SizedBox();
            }

            return ListenableBuilder(
              listenable: Listenable.merge([
                lspService.isRunningNotifier,
                lspService.isInitializingNotifier,
                lspService.workProgressNotifier,
                lspService.workProgressMessage,
              ]),
              builder: (context, _) {
                final isRunning = lspService.isRunningNotifier.value;
                final isInitializing = lspService.isInitializingNotifier.value;
                final hasProgress = lspService.workProgressNotifier.value;
                final progressMessage = lspService.workProgressMessage.value;
                final isStuck = lspService.isAnalysisStuck();

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isInitializing || (hasProgress && !isStuck))
                        SizedBox(
                          width: editorConfigService.config.uiFontSize,
                          height: editorConfigService.config.uiFontSize,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: themeColor,
                          ),
                        )
                      else if (isStuck)
                        Icon(
                          Icons.warning_amber,
                          size: editorConfigService.config.uiFontSize,
                          color: Colors.orange,
                        )
                      else
                        Icon(
                          isRunning ? Icons.check_circle : Icons.cancel,
                          size: editorConfigService.config.uiFontSize,
                          color: isRunning ? Colors.green : Colors.red,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        isStuck
                            ? 'Analysis Stuck'
                            : (hasProgress
                                ? progressMessage
                                : (isRunning
                                    ? (lspService.currentServerName ?? 'LSP')
                                    : (isInitializing
                                        ? 'Starting LSP...'
                                        : 'LSP Failed'))),
                        style: TextStyle(
                          color: themeColor,
                          fontSize: editorConfigService.config.uiFontSize,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (!isInitializing)
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: GestureDetector(
                            onTap: () async {
                              lspService.dispose();
                              await lspService.initialize();
                            },
                            child: Icon(
                              Icons.refresh,
                              size: editorConfigService.config.uiFontSize,
                              color: themeColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLanguageInfo(BuildContext context,
      EditorConfigService editorConfigService, Color themeColor) {
    return Consumer<EditorStateProvider>(
      builder: (context, editorStateProvider, _) {
        return ListenableBuilder(
          listenable: editorStateProvider.editorTabManager,
          builder: (context, _) {
            final language = editorStateProvider.getDetectedLanguage();
            if (language == null) return const SizedBox();

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                language,
                style: TextStyle(
                  color: themeColor,
                  fontSize: editorConfigService.config.uiFontSize,
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EditorConfigService>(
      builder: (context, editorConfigService, _) {
        if (!editorConfigService.isLoaded) {
          return _buildLoadingBar();
        }

        final themeColor =
            editorConfigService.themeService.currentTheme?.text ??
                Colors.black87;
        final primary =
            editorConfigService.themeService.currentTheme?.primary ??
                Colors.blue;
        final backgroundColor =
            editorConfigService.themeService.currentTheme?.background ??
                Colors.white;
        final borderColor =
            editorConfigService.themeService.currentTheme?.border ??
                Colors.grey[300]!;

        return Container(
          height: editorConfigService.config.uiFontSize * 1.8,
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              _buildFileExplorerToggle(
                  context, editorConfigService, primary, themeColor),
              _buildTerminalToggle(
                  context, editorConfigService, primary, themeColor),
              _buildLSPStatus(context, editorConfigService, themeColor),
              const Spacer(),
              _buildLanguageInfo(context, editorConfigService, themeColor),
              _buildCursorInfo(context, editorConfigService, themeColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingBar() {
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

  Widget _buildFileExplorerToggle(
      BuildContext context,
      EditorConfigService editorConfigService,
      Color primary,
      Color themeColor) {
    return Consumer<FileExplorerProvider>(
      builder: (context, fileExplorerProvider, _) {
        return MouseRegion(
          child: GestureDetector(
            onTap: () => fileExplorerProvider.toggle(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                fileExplorerProvider.isVisible
                    ? Icons.folder
                    : Icons.folder_open,
                size: editorConfigService.config.uiFontSize,
                color: fileExplorerProvider.isVisible ? primary : themeColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTerminalToggle(
      BuildContext context,
      EditorConfigService editorConfigService,
      Color primary,
      Color themeColor) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, _) {
        return MouseRegion(
          child: GestureDetector(
            onTap: () => terminalProvider.toggle(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Icon(
                terminalProvider.isTerminalVisible
                    ? Icons.terminal
                    : Icons.terminal_outlined,
                size: editorConfigService.config.uiFontSize,
                color:
                    terminalProvider.isTerminalVisible ? primary : themeColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCursorInfo(BuildContext context,
      EditorConfigService editorConfigService, Color themeColor) {
    return Consumer<EditorStateProvider>(
      builder: (context, editorStateProvider, _) {
        final state = editorStateProvider.editorTabManager.activeEditor;
        if (state == null) return const SizedBox();

        return ListenableBuilder(
          listenable: state.editorCursorManager,
          builder: (context, _) {
            final cursorInfo = state.editorCursorManager.cursors.length > 1
                ? '${state.editorCursorManager.cursors.length} cursors'
                : '${state.editorCursorManager.cursors.first.line + 1}:${state.editorCursorManager.cursors.first.column + 1}';

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                cursorInfo,
                style: TextStyle(
                  color: themeColor,
                  fontSize: editorConfigService.config.uiFontSize,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
