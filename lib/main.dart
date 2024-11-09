import 'dart:async';

import 'package:crystal/app/app.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:window_manager/window_manager.dart';

bool isWindowInitialized = false;
final log = Logger('MainApp');

void main() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    debugPrint('${record.level.name}: ${record.time}: ${record.message}');
  });

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await windowManager.ensureInitialized();

    if (!isWindowInitialized) {
      await setupWindow();
      isWindowInitialized = true;
    }

    final editorConfigService = await EditorConfigService.create();
    final fileService = FileService();
    runApp(App(
      editorConfigService: editorConfigService,
      fileService: fileService,
    ));
  }, (error, stack) {
    log.severe('Uncaught error', error, stack);
  });
}

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
