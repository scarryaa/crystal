import 'dart:io';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class TitleBar extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final Function()? onDirectoryRefresh;

  const TitleBar({
    super.key,
    required this.editorConfigService,
    this.onDirectoryChanged,
    this.onDirectoryRefresh,
  });

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
  String currentDirectory = Directory.current.path;
  bool isHovering = false;
  bool isFullScreen = false;

  @override
  void initState() {
    super.initState();
    _initializeFullScreenListener();
  }

  Future<void> _initializeFullScreenListener() async {
    if (Platform.isMacOS) {
      isFullScreen = await windowManager.isFullScreen();
      windowManager.addListener(this);
    }
  }

  @override
  void onWindowEnterFullScreen() {
    setState(() => isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    setState(() => isFullScreen = false);
  }

  Future<void> _pickDirectory() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();

    if (selectedDirectory != null) {
      setState(() {
        Directory.current = selectedDirectory;
        currentDirectory = selectedDirectory;
      });

      if (widget.onDirectoryChanged != null) {
        widget.onDirectoryChanged!(selectedDirectory);
      }

      if (widget.onDirectoryRefresh != null) {
        widget.onDirectoryRefresh!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.editorConfigService.themeService.currentTheme!;

    return GestureDetector(
      onPanStart: (details) {
        windowManager.startDragging();
      },
      child: Container(
        height: 28,
        color: theme.titleBar,
        child: Row(
          children: [
            if (Platform.isMacOS && !isFullScreen) const SizedBox(width: 70),
            const SizedBox(width: 6),
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
                      Text(
                        currentDirectory.split('/').last,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.text.withOpacity(0.7),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (Platform.isMacOS) {
      windowManager.removeListener(this);
    }
    super.dispose();
  }
}
