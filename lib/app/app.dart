import 'package:crystal/app/app_layout.dart';
import 'package:crystal/main.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  final EditorConfigService editorConfigService;

  const App({
    super.key,
    required this.editorConfigService,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  String? currentDirectory;
  Key _editorKey = UniqueKey();
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    if (!_isInitialized) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    await setupWindow();
    await _loadConfig();
    _isInitialized = true;
  }

  Future<void> _loadConfig() async {
    if (!mounted) return;

    await widget.editorConfigService.loadConfig();

    setState(() {
      if (widget.editorConfigService.config.currentDirectory != null) {
        currentDirectory = widget.editorConfigService.config.currentDirectory;
      }
      _isLoading = false;
    });
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
