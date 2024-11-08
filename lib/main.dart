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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    await widget.editorConfigService.loadConfig();

    if (mounted) {
      setState(() {
        if (widget.editorConfigService.config.currentDirectory != null) {
          currentDirectory = widget.editorConfigService.config.currentDirectory;
        }
        _isLoading = false;
      });
    }
  }

  void _handleDirectoryChanged(String newPath) {
    setState(() {
      currentDirectory = newPath;
      _editorKey = UniqueKey();

      widget.editorConfigService.config.currentDirectory = newPath;
      widget.editorConfigService.saveConfig();
    });
  }

  void _handleDirectoryRefresh() {
    setState(() {
      _editorKey = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MaterialApp(
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

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
        currentDirectory: currentDirectory,
        child: EditorScreen(
          key: _editorKey,
          lineHeightMultipler: 1.5,
          verticalPaddingLines: 5,
          horizontalPadding: 100,
          currentDirectory: currentDirectory,
          onDirectoryChanged: _handleDirectoryChanged,
          onDirectoryRefresh: _handleDirectoryRefresh,
        ),
      ),
    );
  }
}
