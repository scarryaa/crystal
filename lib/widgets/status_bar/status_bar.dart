import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:crystal/widgets/command_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatusBar extends StatelessWidget {
  final EditorTabManager editorTabManager;
  final EditorStateProvider editorStateProvider;

  const StatusBar(
      {required this.editorStateProvider,
      required this.editorTabManager,
      super.key});

  Widget _buildLSPStatus(BuildContext context,
      EditorConfigService editorConfigService, Color themeColor) {
    return Consumer<EditorStateProvider>(
      builder: (context, editorStateProvider, _) {
        return ListenableBuilder(
          listenable: editorStateProvider.editorTabManager,
          builder: (context, _) {
            final activeEditor =
                editorStateProvider.editorTabManager.activeEditor;
            final lspController = activeEditor?.lspController;

            if (activeEditor == null || lspController == null) {
              return const SizedBox();
            }

            return ListenableBuilder(
              listenable: Listenable.merge([
                lspController.isRunningNotifier,
                lspController.isInitializingNotifier,
                lspController.workProgressNotifier,
                lspController.workProgressMessage,
              ]),
              builder: (context, _) {
                final isRunning = lspController.isRunningNotifier.value;
                final isInitializing =
                    lspController.isInitializingNotifier.value;
                final hasProgress = lspController.workProgressNotifier.value;
                final progressMessage = lspController.workProgressMessage.value;
                final isStuck = lspController.isAnalysisStuck();

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
                                    ? (lspController.currentServerName ?? 'LSP')
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
                              lspController.dispose();
                              await lspController.initialize();
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
          listenable: Listenable.merge([
            editorStateProvider.editorTabManager,
            editorStateProvider.languageChangeNotifier,
          ]),
          builder: (context, _) {
            final language = editorStateProvider.detectedLanguage;
            if (language == null) return const SizedBox();

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () =>
                    _showLanguageSelector(context, editorConfigService),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    language.name,
                    style: TextStyle(
                      color: themeColor,
                      fontSize: editorConfigService.config.uiFontSize,
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguageSelector(
      BuildContext context, EditorConfigService editorConfigService) {
    final languages = LanguageDetectionService.getAvailableLanguages();
    showDialog(
      context: context,
      builder: (context) => CommandPalette(
        commands: languages
            .map((lang) => CommandItem(
                  id: lang.toLowerCase,
                  label: lang.name,
                  detail: 'Set file language',
                  category: 'Language',
                  icon: Icons.code,
                  iconColor:
                      editorConfigService.themeService.currentTheme?.text ??
                          Colors.black87,
                ))
            .toList(),
        onSelect: (command) {
          final language =
              LanguageDetectionService.getLanguageFromName(command.id);
          editorStateProvider.updateLanguage(language);
          Navigator.pop(context);
        },
        editorConfigService: editorConfigService,
      ),
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
          listenable: state.cursorController,
          builder: (context, _) {
            final cursorInfo = state.cursors.length > 1
                ? '${state.cursors.length} cursors'
                : '${state.cursors.first.line + 1}:${state.cursors.first.column + 1}';

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
