import 'package:crystal/app_layout.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1280, 720),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  final editorConfigService = await EditorConfigService.create();

  runApp(MyApp(editorConfigService: editorConfigService));
}

class MyApp extends StatefulWidget {
  final EditorConfigService editorConfigService;

  const MyApp({
    super.key,
    required this.editorConfigService,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? currentDirectory;
  Key _editorKey = UniqueKey();

  void _handleDirectoryChanged(String newPath) {
    setState(() {
      currentDirectory = newPath;
      _editorKey = UniqueKey();
    });
  }

  void _handleDirectoryRefresh() {
    setState(() {
      _editorKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'crystal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        fontFamily: 'IBM Plex Sans',
      ),
      home: AppLayout(
        editorConfigService: widget.editorConfigService,
        onDirectoryChanged: _handleDirectoryChanged,
        onDirectoryRefresh: _handleDirectoryRefresh,
        child: EditorScreen(
          key: _editorKey,
          lineHeightMultipler: 1.5,
          verticalPaddingLines: 5,
          horizontalPadding: 100,
          currentDirectory: currentDirectory,
        ),
      ),
    );
  }
}
