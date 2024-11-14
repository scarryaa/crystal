import 'package:crystal/providers/terminal_provider.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/widgets/terminal/terminal_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TerminalSection extends StatelessWidget {
  final EditorConfigService editorConfigService;

  const TerminalSection({
    super.key,
    required this.editorConfigService,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<TerminalProvider>(
      builder: (context, terminalProvider, child) {
        if (!terminalProvider.isTerminalVisible ||
            terminalProvider.terminalHeight <= 0) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            GestureDetector(
              onVerticalDragUpdate: (details) {
                terminalProvider.updateHeight(details.delta.dy);
              },
              onVerticalDragEnd: (_) {
                terminalProvider.saveHeight();
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeRow,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: editorConfigService
                        .themeService.currentTheme?.background,
                  ),
                ),
              ),
            ),
            Container(
              height: terminalProvider.terminalHeight - 2,
              color: editorConfigService.themeService.currentTheme?.background,
              child: EditorTerminalView(
                editorConfigService: editorConfigService,
                onLastTabClosed: () {
                  terminalProvider.setVisibility(false);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
