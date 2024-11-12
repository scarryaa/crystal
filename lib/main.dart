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

    // Check for updates during normal startup
    try {
      final updateInfo = await checkForUpdates('scarryaa/crystal');
      if (updateInfo.hasUpdate) {
        log.info('Update available: ${updateInfo.version}');
        return;
      }
    } catch (e) {
      log.warning('Failed to check for updates: $e');
    }

    // Normal app startup
    if (Platform.isWindows) {
      await windowManager.ensureInitialized();
      await windowManager.waitUntilReadyToShow();
      await windowManager.setSize(const Size(1280, 720));
      await windowManager.center();
      await windowManager.show();
    } else {
      await windowManager.ensureInitialized();
      if (!isWindowInitialized) {
        await setupWindow();
        isWindowInitialized = true;
      }
    }

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
