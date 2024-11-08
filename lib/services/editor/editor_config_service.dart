import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
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
    'whitespaceIndicatorRadius': 1.0,
    'theme': 'default-dark',
    'isFileExplorerVisible': true,
    'currentDirectory': '',
  };

  EditorConfigService._() : themeService = EditorThemeService();

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
        Future.delayed(const Duration(milliseconds: 100), () async {
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
        whitespaceIndicatorRadius:
            (configData['whitespaceIndicatorRadius'] as num?)?.toDouble() ??
                _defaultConfig['whitespaceIndicatorRadius'] as double,
        isFileExplorerVisible: configData['isFileExplorerVisible'] as bool? ??
            _defaultConfig['isFileExplorerVisible'] as bool,
        currentDirectory: configData['currentDirectory'] as String? ??
            _defaultConfig['currentDirectory'] as String,
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
      whitespaceIndicatorRadius:
          _defaultConfig['whitespaceIndicatorRadius'] as double,
      isFileExplorerVisible: _defaultConfig['isFileExplorerVisible'] as bool,
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
        'theme': themeService.currentTheme!.name,
        'whitespaceIndicatorRadius': config.whitespaceIndicatorRadius,
        'isFileExplorerVisible': config.isFileExplorerVisible,
        'currentDirectory': config.currentDirectory,
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
    await themeService.loadThemeFromJson(_defaultConfig['theme'] as String);
  }
}
