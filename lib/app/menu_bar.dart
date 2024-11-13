import 'dart:io' show Platform, exit;
import 'dart:math' as math;
import 'package:crystal/app/updater.dart';
import 'package:crystal/app/window_button.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class AppMenuBar extends StatefulWidget {
  final Function(String) onDirectoryChanged;
  final FileService fileService;
  final EditorConfigService editorConfigService;
  final GlobalKey<EditorScreenState> editorKey;

  const AppMenuBar({
    super.key,
    required this.onDirectoryChanged,
    required this.fileService,
    required this.editorConfigService,
    required this.editorKey,
  });

  @override
  State<AppMenuBar> createState() => _AppMenuBarState();
}

class _AppMenuBarState extends State<AppMenuBar> {
  Map<String, bool> hoverStates = {};
  OverlayEntry? _overlayEntry;
  bool isDirectoryButtonHovered = false;
  bool isHovering = false;
  bool isFullScreen = false;
  bool isMaximized = false;

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
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

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Failed to check for updates: $e'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _showMenu(
      BuildContext context, List<MenuItemData> items, Offset position) {
    final theme = widget.editorConfigService.themeService.currentTheme!;

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
              },
            ),
          ),
          Positioned(
            top: position.dy,
            left: position.dx,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(4),
              color: theme.titleBar, // Use theme color for popup
              child: IntrinsicWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: items
                      .map((item) => _buildMenuItem(context, item, theme))
                      .toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  Widget _buildMenuItem(
      BuildContext context, MenuItemData item, dynamic theme) {
    if (item.isDivider) {
      return Divider(
        height: 1,
        color: theme.text.withOpacity(0.1),
      );
    }

    return StatefulBuilder(
      builder: (context, setState) {
        return MouseRegion(
          onEnter: (_) => setState(() => hoverStates[item.label] = true),
          onExit: (_) => setState(() => hoverStates[item.label] = false),
          child: Container(
            decoration: BoxDecoration(
              color: hoverStates[item.label] == true
                  ? theme.text.withOpacity(0.1)
                  : Colors.transparent,
            ),
            child: InkWell(
              onTap: () {
                _overlayEntry?.remove();
                _overlayEntry = null;
                item.onTap?.call();
              },
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: TextStyle(color: theme.text),
                      ),
                    ),
                    if (item.shortcut != null)
                      Text(
                        _getShortcutLabel(item.shortcut!),
                        style: TextStyle(
                          color: theme.text.withOpacity(0.5),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDirectoryButton() {
    final theme = widget.editorConfigService.themeService.currentTheme!;
    final hasDirectory = widget.fileService.rootDirectory.isNotEmpty;

    return MouseRegion(
      onEnter: (_) => setState(() => isDirectoryButtonHovered = true),
      onExit: (_) => setState(() => isDirectoryButtonHovered = false),
      child: GestureDetector(
        onTap: () async {
          final selectedDirectory =
              await FilePicker.platform.getDirectoryPath();
          if (selectedDirectory != null) {
            widget.onDirectoryChanged(selectedDirectory);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isDirectoryButtonHovered
                ? theme.text.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasDirectory) ...[
                Text(
                  widget.fileService.rootDirectory
                      .split(Platform.pathSeparator)
                      .last,
                  style: TextStyle(
                    color: theme.text.withOpacity(0.7),
                    fontSize: widget.editorConfigService.config.uiFontSize,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getShortcutLabel(SingleActivator shortcut) {
    final isMac = Platform.isMacOS;
    final meta = shortcut.meta ? (isMac ? '⌘' : 'Ctrl+') : '';
    final shift = shortcut.shift ? (isMac ? '⇧' : 'Shift+') : '';
    final key = shortcut.trigger.keyLabel;
    return '$meta$shift$key';
  }

  @override
  Widget build(BuildContext context) {
    if (Platform.isMacOS) return const SizedBox.shrink();

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
              if (Platform.isMacOS) const SizedBox(width: 70),
              const SizedBox(width: 6),
              _buildDirectoryButton(),
              _MenuButton(
                label: 'File',
                items: [
                  MenuItemData(
                    label: 'Open Directory...',
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyO,
                        meta: true),
                    onTap: () async {
                      final selectedDirectory =
                          await FilePicker.platform.getDirectoryPath();
                      if (selectedDirectory != null) {
                        widget.onDirectoryChanged(selectedDirectory);
                      }
                    },
                  ),
                  MenuItemData(
                    label: 'Check for Updates...',
                    onTap: () => _checkForUpdates(context),
                  ),
                  if (Platform.isMacOS) ...[
                    MenuItemData(isDivider: true),
                    MenuItemData(
                      label: 'Quit',
                      shortcut: const SingleActivator(LogicalKeyboardKey.keyQ,
                          meta: true),
                      onTap: () => exit(0),
                    ),
                  ],
                ],
                onShow: _showMenu,
                theme: theme,
              ),
              _MenuButton(
                label: 'Edit',
                items: [
                  MenuItemData(
                    label: 'Undo',
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyZ,
                        meta: true),
                    onTap: () {
                      final editorState = widget.editorKey.currentState;
                      if (editorState != null) {
                        final activeEditor =
                            editorState.editorTabManager.activeEditor;
                        activeEditor?.undo();
                      }
                    },
                  ),
                  MenuItemData(
                    label: 'Redo',
                    shortcut: const SingleActivator(LogicalKeyboardKey.keyZ,
                        meta: true, shift: true),
                    onTap: () {
                      final editorState = widget.editorKey.currentState;
                      if (editorState != null) {
                        final activeEditor =
                            editorState.editorTabManager.activeEditor;
                        activeEditor?.redo();
                      }
                    },
                  ),
                ],
                onShow: _showMenu,
                theme: theme,
              ),
              _MenuButton(
                label: 'View',
                items: [
                  MenuItemData(
                    label: 'Increase Font Size',
                    shortcut: const SingleActivator(LogicalKeyboardKey.equal,
                        meta: true),
                    onTap: () {
                      var config = widget.editorConfigService.config;
                      config.fontSize += 2;
                      widget.editorConfigService.saveConfig();
                    },
                  ),
                  MenuItemData(
                    label: 'Decrease Font Size',
                    shortcut: const SingleActivator(LogicalKeyboardKey.minus,
                        meta: true),
                    onTap: () {
                      var config = widget.editorConfigService.config;
                      config.uiFontSize = math.max(8, config.uiFontSize - 2);
                      widget.editorConfigService.saveConfig();
                    },
                  ),
                ],
                onShow: _showMenu,
                theme: theme,
              ),
              const Spacer(),
              _buildWindowButtons(),
            ],
          ),
        ));
  }

  Widget _buildWindowButtons() {
    if (!Platform.isWindows && !Platform.isLinux) return const SizedBox();

    return Row(
      children: [
        WindowButton(
          icon: Icons.remove,
          onPressed: () async => await windowManager.minimize(),
          color: widget.editorConfigService.themeService.currentTheme!.text,
        ),
        WindowButton(
          icon: isMaximized ? Icons.crop_square : Icons.crop_square_outlined,
          onPressed: () async {
            if (isMaximized) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
          color: widget.editorConfigService.themeService.currentTheme!.text,
        ),
        WindowButton(
          icon: Icons.close,
          onPressed: () async => await windowManager.close(),
          color: widget.editorConfigService.themeService.currentTheme!.text,
          isClose: true,
        ),
      ],
    );
  }
}

class _MenuButton extends StatefulWidget {
  final String label;
  final List<MenuItemData> items;
  final Function(BuildContext, List<MenuItemData>, Offset) onShow;
  final dynamic theme;

  const _MenuButton({
    required this.label,
    required this.items,
    required this.onShow,
    required this.theme,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: Container(
        decoration: BoxDecoration(
          color: isHovering
              ? widget.theme.text.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: InkWell(
          onTap: () {
            final RenderBox button = context.findRenderObject() as RenderBox;
            final Offset position = button.localToGlobal(
              Offset(0, button.size.height),
            );
            widget.onShow(context, widget.items, position);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Center(
              child: Text(
                widget.label,
                style: TextStyle(
                  color: widget.theme.text,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MenuItemData {
  final String label;
  final SingleActivator? shortcut;
  final VoidCallback? onTap;
  final bool isDivider;

  MenuItemData({
    this.label = '',
    this.shortcut,
    this.onTap,
    this.isDivider = false,
  });
}
