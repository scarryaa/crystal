import 'dart:io';

import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final GlobalKey<EditorScreenState> editorKey;

  const TitleBar({
    super.key,
    required this.editorConfigService,
    required this.onDirectoryChanged,
    required this.fileService,
    required this.editorKey,
  });

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  bool isHovering = false;
  bool isFullScreen = false;
  bool isMaximized = false;

  @override
  void initState() {
    super.initState();
    _initializeWindowListeners();
  }

  Future<void> _initializeWindowListeners() async {
    if (Platform.isMacOS) {
      isFullScreen = await windowManager.isFullScreen();
    } else if (Platform.isWindows || Platform.isLinux) {
      isMaximized = await windowManager.isMaximized();
    }
    windowManager.addListener(this);
  }

  @override
  void onWindowMaximize() {
    setState(() => isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => isMaximized = false);
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      Directory.current = selectedDirectory;

      widget.onDirectoryChanged?.call(selectedDirectory);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
        listenable: Listenable.merge([
          widget.editorConfigService,
          widget.editorConfigService.themeService,
        ]),
        builder: (context, child) {
          final theme = widget.editorConfigService.themeService.currentTheme!;

          return GestureDetector(
            onPanStart: (details) {
              windowManager.startDragging();
            },
            onDoubleTap: Platform.isWindows || Platform.isLinux
                ? () async {
                    if (isMaximized) {
                      await windowManager.unmaximize();
                    } else {
                      await windowManager.maximize();
                    }
                  }
                : null,
            child: Container(
              height: widget.editorConfigService.config.uiFontSize * 2.0,
              color: theme.titleBar,
              child: Row(
                children: [
                  if (Platform.isMacOS && !isFullScreen)
                    const SizedBox(width: 70),
                  const SizedBox(width: 6),
                  // Directory Button
                  MouseRegion(
                    onEnter: (_) => setState(() => isHovering = true),
                    onExit: (_) => setState(() => isHovering = false),
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _pickDirectory,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: isHovering
                              ? theme.text.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.fileService.rootDirectory.isNotEmpty)
                              Text(
                                widget.fileService.rootDirectory
                                    .split(Platform.pathSeparator)
                                    .last,
                                style: TextStyle(
                                  fontSize: widget
                                      .editorConfigService.config.uiFontSize,
                                  color: theme.text.withOpacity(0.7),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        });
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
