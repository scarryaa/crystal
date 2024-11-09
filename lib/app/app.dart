import 'package:crystal/app/app_layout.dart';
import 'package:crystal/main.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class App extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final FileService fileService;

  const App({
    super.key,
    required this.editorConfigService,
    required this.fileService,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
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
        widget.fileService.rootDirectory =
            widget.editorConfigService.config.currentDirectory ?? '';
      }
      _isLoading = false;
    });
  }

  void _handleDirectoryChanged(String newPath) {
    setState(() {
      widget.fileService.setRootDirectory(newPath);
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
        iconTheme: IconThemeData(
          size: widget.editorConfigService.config.uiFontSize,
          color: widget.editorConfigService.themeService.currentTheme != null
              ? widget.editorConfigService.themeService.currentTheme!.primary
              : Colors.blue,
          opacity: 1.0,
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 57,
            fontWeight: FontWeight.w400,
          ),
          displayMedium: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 45,
            fontWeight: FontWeight.w400,
          ),
          displaySmall: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 36,
            fontWeight: FontWeight.w400,
          ),
          headlineLarge: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 32,
            fontWeight: FontWeight.w400,
          ),
          headlineMedium: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 28,
            fontWeight: FontWeight.w400,
          ),
          headlineSmall: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 24,
            fontWeight: FontWeight.w400,
          ),
          titleLarge: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 22,
            fontWeight: FontWeight.w400,
          ),
          titleMedium: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
          titleSmall: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          bodyMedium: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          bodySmall: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
          labelLarge: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          labelMedium: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          labelSmall: TextStyle(
            fontFamily: 'IBM Plex Sans',
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        typography: Typography.material2021(
          platform: defaultTargetPlatform,
          black: Typography.blackMountainView.copyWith(
            bodyLarge: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            bodyMedium: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            bodySmall: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
          white: Typography.whiteMountainView.copyWith(
            bodyLarge: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            bodyMedium: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
            bodySmall: const TextStyle(
              fontFamily: 'IBM Plex Sans',
              fontSize: 12,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
      home: AppLayout(
        editorConfigService: widget.editorConfigService,
        onDirectoryChanged: _handleDirectoryChanged,
        onDirectoryRefresh: _handleDirectoryRefresh,
        fileService: widget.fileService,
        child: EditorScreen(
          key: _editorKey,
          lineHeightMultipler: 1.5,
          verticalPaddingLines: 5,
          horizontalPadding: 100,
          fileService: widget.fileService,
          onDirectoryChanged: _handleDirectoryChanged,
          onDirectoryRefresh: _handleDirectoryRefresh,
        ),
      ),
    );
  }
}
