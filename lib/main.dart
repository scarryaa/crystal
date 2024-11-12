import 'dart:async';
import 'dart:io';

import 'package:crystal/app/app.dart';
import 'package:crystal/app/updater.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

bool isWindowInitialized = false;
final log = Logger('MainApp');

Future<void> setupWindow() async {
  const windowOptions = WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'crystal',
  );

  await windowManager.setSize(windowOptions.size ?? const Size(1280, 720));
  await windowManager.center();
  await windowManager.setBackgroundColor(Colors.transparent);
  await windowManager.setSkipTaskbar(windowOptions.skipTaskbar ?? false);
  await windowManager
      .setTitleBarStyle(windowOptions.titleBarStyle ?? TitleBarStyle.hidden);
  await windowManager.setTitle(windowOptions.title ?? 'crystal');

  await windowManager.show();
  await windowManager.focus();
}

Future<bool?> showUpdateDialog(String version) async {
  final completer = Completer<bool?>();

  runApp(MaterialApp(
    home: Builder(
      builder: (context) {
        // Show dialog after the app is built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Update Available'),
              content: Text(
                  'Version $version is available. Would you like to update now?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Later'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ).then((value) => completer.complete(value));
        });
        return const Scaffold(backgroundColor: Colors.transparent);
      },
    ),
  ));

  return completer.future;
}

void main(List<String> arguments) {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Check if running in update mode
    if (arguments.contains('--update')) {
      await performUpdate();
      return;
    }

    // Skip update check if in development mode
    final bool isDevelopment = arguments.contains('--dev') ||
        const bool.fromEnvironment('FLUTTER_DEV');

    // Initialize window first for update prompt
    await windowManager.ensureInitialized();
    if (Platform.isWindows) {
      await windowManager.waitUntilReadyToShow();
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.center();
      await windowManager.show();
    } else if (!isWindowInitialized) {
      await setupWindow();
      isWindowInitialized = true;
    }

    // Check for updates during normal startup
    if (!isDevelopment) {
      try {
        final updateInfo = await checkForUpdates('scarryaa/crystal');
        if (updateInfo.hasUpdate) {
          log.info('Update available: ${updateInfo.version}');

          final shouldUpdate = await showUpdateDialog(updateInfo.version!);
          if (shouldUpdate == true) {
            await launchUpdater();
            return;
          }
        }
      } catch (e) {
        log.warning('Failed to check for updates: $e');
      }
    }

    // Normal app startup
    final editorConfigService = await EditorConfigService.create();
    final fileService = FileService();
    runApp(App(
      editorConfigService: editorConfigService,
      fileService: fileService,
    ));
  }, (error, stack) {
    log.severe('Uncaught error: $error\n$stack');
  });
}
