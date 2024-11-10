import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class EditorConfigService extends ChangeNotifier {
  StreamSubscription<FileSystemEvent>? _configFileWatcher;
  final EditorThemeService themeService;
  late EditorConfig config;
  final _logger = Logger('EditorConfigService');
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  static const Map<String, dynamic> _defaultConfig = {
    'fontSize': 14.0,
    'uiFontSize': 14.0,
    'fontFamily': 'IBM Plex Mono',
    'uiFontFamily': 'IBM Plex Sans',
    'whitespaceIndicatorRadius': 1.0,
    'theme': 'default-dark',
    'isFileExplorerVisible': true,
    'isFileExplorerOnLeft': true,
    'currentDirectory': '',
    'fileExplorerWidth': 170.0,
    'tabWidth': 4.0, // Add this line
  };

  EditorConfigService._() : themeService = EditorThemeService() {
    EditorLayoutService(
      horizontalPadding: 16.0,
      verticalPaddingLines: 2,
      fontSize: _defaultConfig['fontSize'] as double,
      fontFamily: _defaultConfig['fontFamily'] as String,
      lineHeightMultiplier: 1.5,
    );
  }

  void updateLayoutService() {
    EditorLayoutService.instance.updateFontSize(
      config.fontSize,
      config.fontFamily,
    );
  }

  static Future<EditorConfigService> create() async {
    final service = EditorConfigService._();
    await service.loadConfig();
    await service.saveDefaultConfig();
    await service._watchConfigFile();
    return service;
  }

  @override
  void dispose() {
    _configFileWatcher?.cancel();
    super.dispose();
  }

  Future<void> loadConfig() async {
    try {
      final configFile = File(await ConfigPaths.getConfigFilePath());
      config = await _loadConfigFromFile(configFile);
      await _loadTheme();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error loading config: $e');
      if (!_isLoaded) {
        await _setDefaultConfig();
      }
    }
  }

  Future<void> _watchConfigFile() async {
    final configPath = await ConfigPaths.getConfigFilePath();
    _configFileWatcher?.cancel();

    _configFileWatcher = File(configPath)
        .watch(events: FileSystemEvent.modify)
        .listen((FileSystemEvent event) {
      if (event.type == FileSystemEvent.modify) {
        Future.delayed(const Duration(milliseconds: 1), () async {
          await loadConfig();
        });
      }
    });
  }

  Future<EditorConfig> _loadConfigFromFile(File configFile) async {
    if (!await configFile.exists()) {
      return _createDefaultConfig();
    }

    try {
      final jsonString = await configFile.readAsString();
      final Map<String, dynamic> configData = json.decode(jsonString);

      return EditorConfig(
        fontSize: (configData['fontSize'] as num?)?.toDouble() ??
            _defaultConfig['fontSize'] as double,
        uiFontSize: (configData['uiFontSize'] as num?)?.toDouble() ??
            _defaultConfig['uiFontSize'] as double,
        fontFamily: configData['fontFamily'] as String? ??
            _defaultConfig['fontFamily'] as String,
        uiFontFamily: configData['uiFontFamily'] as String? ??
            _defaultConfig['uiFontFamily'] as String,
        whitespaceIndicatorRadius:
            (configData['whitespaceIndicatorRadius'] as num?)?.toDouble() ??
                _defaultConfig['whitespaceIndicatorRadius'] as double,
        theme: (configData['theme'] as String?)?.toString() ??
            _defaultConfig['theme'] as String,
        fileExplorerWidth:
            (configData['fileExplorerWidth'] as num?)?.toDouble() ??
                _defaultConfig['fileExplorerWidth'] as double,
        isFileExplorerVisible: configData['isFileExplorerVisible'] as bool? ??
            _defaultConfig['isFileExplorerVisible'] as bool,
        isFileExplorerOnLeft: configData['isFileExplorerOnLeft'] as bool? ??
            _defaultConfig['isFileExplorerOnLeft'] as bool,
        currentDirectory: configData['currentDirectory'] as String? ??
            _defaultConfig['currentDirectory'] as String,
        tabWidth:
            (configData['tabWidth'] as num?)?.toDouble() ?? // Add this line
                _defaultConfig['tabWidth'] as double,
      );
    } catch (e) {
      _logger.warning('Error parsing config file: $e');
      return _createDefaultConfig();
    }
  }

  EditorConfig _createDefaultConfig() {
    return EditorConfig(
      fontSize: _defaultConfig['fontSize'] as double,
      uiFontSize: _defaultConfig['uiFontSize'] as double,
      fontFamily: _defaultConfig['fontFamily'] as String,
      uiFontFamily: _defaultConfig['uiFontFamily'] as String,
      theme: _defaultConfig['theme'] as String,
      whitespaceIndicatorRadius:
          _defaultConfig['whitespaceIndicatorRadius'] as double,
      fileExplorerWidth: (_defaultConfig['uiFontSize'] as double) * 11.0,
      isFileExplorerVisible: _defaultConfig['isFileExplorerVisible'] as bool,
      isFileExplorerOnLeft: _defaultConfig['isFileExplorerOnLeft'] as bool,
      currentDirectory: _defaultConfig['currentDirectory'] as String,
      tabWidth: _defaultConfig['tabWidth'] as double, // Add this line
    );
  }

  Future<void> _setDefaultConfig() async {
    if (!_isLoaded) {
      config = _createDefaultConfig();
      await themeService.loadThemeFromJson(_defaultConfig['theme'] as String);
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> saveConfig() async {
    try {
      final configPath = await ConfigPaths.getConfigFilePath();
      final configData = {
        'fontSize': config.fontSize,
        'uiFontSize': config.uiFontSize,
        'fontFamily': config.fontFamily,
        'uiFontFamily': config.uiFontFamily,
        'theme': themeService.currentTheme!.name,
        'whitespaceIndicatorRadius': config.whitespaceIndicatorRadius,
        'isFileExplorerVisible': config.isFileExplorerVisible,
        'isFileExplorerOnLeft': config.isFileExplorerOnLeft,
        'currentDirectory': config.currentDirectory,
        'fileExplorerWidth': config.fileExplorerWidth,
        'tabWidth': config.tabWidth, // Add this line
      };

      const encoder = JsonEncoder.withIndent('  ');
      await File(configPath).writeAsString(encoder.convert(configData));
    } catch (e) {
      _logger.warning('Error saving config: $e');
    }
  }

  Future<void> saveDefaultConfig() async {
    try {
      final configPath = await ConfigPaths.getDefaultConfigFilePath();
      const encoder = JsonEncoder.withIndent('  ');
      await File(configPath).writeAsString(encoder.convert(_defaultConfig));
    } catch (e) {
      _logger.warning('Error saving default config: $e');
    }
  }

  Future<void> _loadTheme() async {
    await themeService.loadThemeFromJson(config.theme);
  }
}
