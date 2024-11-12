import 'dart:io' show Platform, exit;
import 'dart:math' as math;
import 'package:crystal/app/updater.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppMenuBar extends StatelessWidget {
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

  Future<String?> _getDirectoryPath() async {
    return FilePicker.platform.getDirectoryPath();
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

  @override
  Widget build(BuildContext context) {
    return PlatformMenuBar(
      menus: [
        PlatformMenu(
          label: 'File',
          menus: [
            PlatformMenuItem(
              label: 'Open Directory...',
              onSelected: () async {
                final selectedDirectory = await _getDirectoryPath();
                if (selectedDirectory != null) {
                  onDirectoryChanged(selectedDirectory);
                }
              },
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyO, meta: true),
            ),
            PlatformMenuItem(
              label: 'Check for Updates...',
              onSelected: () => _checkForUpdates(context),
            ),
            if (Platform.isMacOS) ...[
              PlatformMenuItem(
                label: 'Quit',
                shortcut:
                    const SingleActivator(LogicalKeyboardKey.keyQ, meta: true),
                onSelected: () {
                  exit(0);
                },
              ),
            ],
          ],
        ),
        PlatformMenu(
          label: 'Edit',
          menus: [
            PlatformMenuItem(
              label: 'Undo',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
              onSelected: () {
                final editorState = editorKey.currentState;
                if (editorState != null) {
                  final activeEditor =
                      editorState.editorTabManager.activeEditor;
                  activeEditor?.undo();
                }
              },
            ),
            PlatformMenuItem(
              label: 'Redo',
              shortcut: const SingleActivator(LogicalKeyboardKey.keyZ,
                  meta: true, shift: true),
              onSelected: () {
                final editorState = editorKey.currentState;
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
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.equal, meta: true),
              onSelected: () {
                var config = editorConfigService.config;
                config.fontSize += 2;
                editorConfigService.saveConfig();
              },
            ),
            PlatformMenuItem(
              label: 'Decrease Font Size',
              shortcut:
                  const SingleActivator(LogicalKeyboardKey.minus, meta: true),
              onSelected: () {
                var config = editorConfigService.config;
                config.uiFontSize = math.max(8, config.uiFontSize - 2);
                editorConfigService.saveConfig();
              },
            ),
          ],
        ),
      ],
    );
  }
}

