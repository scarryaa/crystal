import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StatusBar extends StatefulWidget {
  EditorConfigService editorConfigService;

  StatusBar({super.key, required this.editorConfigService});

  @override
  State<StatusBar> createState() => _StatusBarState();
}

class _StatusBarState extends State<StatusBar> {
  @override
  Widget build(BuildContext context) {
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
          const Spacer(),
          Consumer<EditorState?>(
            builder: (context, state, child) {
              if (state == null) return const SizedBox();

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${state.cursor.line + 1}:${state.cursor.column + 1}',
                  style: TextStyle(
                    color: widget.editorConfigService.themeService
                                .currentTheme !=
                            null
                        ? widget
                            .editorConfigService.themeService.currentTheme!.text
                        : Colors.black87,
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
