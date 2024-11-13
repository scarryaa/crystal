import 'dart:io';
import 'dart:math' as math;

import 'package:crystal/app/updater.dart';
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

        if (Platform.isMacOS) {
          return PlatformMenuBar(
            menus: [
              PlatformMenu(
                label: 'File',
                menus: [
                  PlatformMenuItem(
                    label: 'Open Directory...',
                    onSelected: () async {
                      final selectedDirectory =
                          await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectory != null) {
                        widget.onDirectoryChanged?.call(selectedDirectory);
                      }
                    },
                  ),
                  PlatformMenuItem(
                    label: 'Check for Updates...',
                    onSelected: () => _checkForUpdates(context),
                  ),
                ],
              ),
              PlatformMenu(
                label: 'Edit',
                menus: [
                  PlatformMenuItem(
                    label: 'Undo',
                    onSelected: () {
                      final editorState = widget.editorKey.currentState;
                      if (editorState != null) {
                        final activeEditor =
                            editorState.editorTabManager.activeEditor;
                        activeEditor?.undo();
                      }
                    },
                  ),
                  PlatformMenuItem(
                    label: 'Redo',
                    onSelected: () {
                      final editorState = widget.editorKey.currentState;
                      if (editorState != null) {
                        final activeEditor =
                            editorState.editorTabManager.activeEditor;
                        activeEditor?.redo();
                      }
                    },
                  ),
                ],
              ),
              PlatformMenu(
                label: 'View',
                menus: [
                  PlatformMenuItem(
                    label: 'Increase Font Size',
                    onSelected: () {
                      var config = widget.editorConfigService.config;
                      config.fontSize += 2;
                      widget.editorConfigService.saveConfig();
                    },
                  ),
                  PlatformMenuItem(
                    label: 'Decrease Font Size',
                    onSelected: () {
                      var config = widget.editorConfigService.config;
                      config.uiFontSize = math.max(8, config.uiFontSize - 2);
                      widget.editorConfigService.saveConfig();
                    },
                  ),
                ],
              ),
            ],
            child: GestureDetector(
              onPanStart: (details) {
                windowManager.startDragging();
              },
              child: Container(
                height: widget.editorConfigService.config.uiFontSize * 2.0,
                color: theme.titleBar,
                child: Row(
                  children: [
                    if (!isFullScreen) const SizedBox(width: 70),
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
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Future<void> _checkForUpdates(BuildContext context) async {
    try {
      final updateInfo = await checkForUpdates('scarryaa/crystal');

      if (!context.mounted) return;

      if (updateInfo.hasUpdate) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Update Available'),
            content: Text(
                'A new version ${updateInfo.version} is available. Would you like to update now?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Later'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await launchUpdater();
                },
                child: const Text('Update Now'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('No Updates Available'),
            content: const Text('You are using the latest version.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      // Show error dialog
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }
}
