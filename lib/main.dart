import 'package:crystal/app/app.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize window settings
  await setupWindow();

  // Initialize editor config service
  final editorConfigService = await EditorConfigService.create();

  runApp(App(editorConfigService: editorConfigService));
}

Future<void> setupWindow() async {
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    title: 'Crystal Editor',
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
