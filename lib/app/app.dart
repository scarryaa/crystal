import 'package:crystal/app/app_layout.dart';
import 'package:crystal/app/menu_bar.dart';
import 'package:crystal/main.dart';
import 'package:crystal/providers/editor_state_provider.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/notification_service.dart';
import 'package:crystal/widgets/dialog_listener.dart';
import 'package:crystal/widgets/notification_overlay.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class App extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final FileService fileService;
  final NotificationService notificationService;

  const App({
    super.key,
    required this.editorConfigService,
    required this.fileService,
    required this.notificationService,
  });

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  late final GlobalKey<EditorScreenState> _editorKey;
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _editorKey = GlobalKey<EditorScreenState>();
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
      widget.editorConfigService.config.currentDirectory = newPath;
      widget.editorConfigService.saveConfig();
      widget.fileService.filesFuture =
          widget.fileService.enumerateFiles(newPath);
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

    return ListenableBuilder(
        listenable: Listenable.merge([
          widget.editorConfigService,
          widget.notificationService,
        ]),
        builder: (context, builder) {
          return MaterialApp(
              title: 'crystal',
              debugShowCheckedModeBanner: false,
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                useMaterial3: true,
                fontFamily: widget.editorConfigService.config.uiFontFamily,
                iconTheme: IconThemeData(
                  size: widget.editorConfigService.config.uiFontSize,
                  color:
                      widget.editorConfigService.themeService.currentTheme !=
                              null
                          ? widget.editorConfigService.themeService
                              .currentTheme!.primary
                          : Colors.blue,
                  opacity: 1.0,
                ),
                textTheme: TextTheme(
                  displayLarge: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 57,
                    fontWeight: FontWeight.w400,
                  ),
                  displayMedium: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 45,
                    fontWeight: FontWeight.w400,
                  ),
                  displaySmall: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 36,
                    fontWeight: FontWeight.w400,
                  ),
                  headlineLarge: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 32,
                    fontWeight: FontWeight.w400,
                  ),
                  headlineMedium: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                  ),
                  headlineSmall: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                  ),
                  titleLarge: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                  ),
                  titleMedium: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  titleSmall: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  bodyLarge: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  bodyMedium: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  bodySmall: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                  labelLarge: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  labelMedium: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  labelSmall: TextStyle(
                    fontFamily: widget.editorConfigService.config.uiFontFamily,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                typography: Typography.material2021(
                  platform: defaultTargetPlatform,
                  black: Typography.blackMountainView.copyWith(
                    bodyLarge: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    bodyMedium: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    bodySmall: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  white: Typography.whiteMountainView.copyWith(
                    bodyLarge: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    bodyMedium: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    bodySmall: TextStyle(
                      fontFamily:
                          widget.editorConfigService.config.uiFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ),
              home: DialogListener(
                  child: MultiProvider(
                      providers: [
                    ChangeNotifierProvider(
                      create: (context) => EditorStateProvider(
                        editorTabManager: EditorTabManager(
                          fileService: widget.fileService,
                          onDirectoryChanged: _handleDirectoryChanged,
                        ),
                      ),
                    )
                  ],
                      child: Stack(children: [
                        Column(
                          children: [
                            Material(
                                child: AppMenuBar(
                              onDirectoryChanged: _handleDirectoryChanged,
                              fileService: widget.fileService,
                              editorConfigService: widget.editorConfigService,
                              editorKey: _editorKey,
                            )),
                            Expanded(
                              child: AppLayout(
                                editorConfigService: widget.editorConfigService,
                                onDirectoryChanged: _handleDirectoryChanged,
                                fileService: widget.fileService,
                                editorKey: _editorKey,
                                child: EditorScreen(
                                  key: _editorKey,
                                  lineHeightMultipler: 1.5,
                                  verticalPaddingLines: 5,
                                  horizontalPadding: 100,
                                  fileService: widget.fileService,
                                  onDirectoryChanged: _handleDirectoryChanged,
                                ),
                              ),
                            ),
                          ],
                        ),
                        NotificationOverlay(
                          notifications:
                              widget.notificationService.notifications,
                          onDismiss: widget.notificationService.dismiss,
                          editorConfigService: widget.editorConfigService,
                        ),
                      ]))));
        });
  }
}
