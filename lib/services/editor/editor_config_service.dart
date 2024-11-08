import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class EditorConfigService extends ChangeNotifier {
  final EditorThemeService themeService;
  late EditorConfig config;
  final _logger = Logger('EditorConfigService');
  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  static const Map<String, dynamic> _defaultConfig = {
    'fontSize': 14.0,
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
    return service;
  }

  Future<void> loadConfig() async {
    if (_isLoaded) return;

    try {
      final configFile = File(await ConfigPaths.getConfigFilePath());
      config = await _loadConfigFromFile(configFile);
      await _loadTheme();
      _isLoaded = true;
      notifyListeners();
    } catch (e) {
      _logger.warning('Error loading config: $e');
      await _setDefaultConfig();
    }
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
        'fontFamily': config.fontFamily,
        'theme': themeService.currentTheme!.name,
        'whitespaceIndicatorRadius': config.whitespaceIndicatorRadius,
        'isFileExplorerVisible': config.isFileExplorerVisible,
        'currentDirectory': config.currentDirectory,
      };

      await File(configPath).writeAsString(json.encode(configData));
    } catch (e) {
      _logger.warning('Error saving config: $e');
    }
  }

  Future<void> _loadTheme() async {
    await themeService.loadThemeFromJson(_defaultConfig['theme'] as String);
  }

  Future<void> saveDefaultConfig() async {
    try {
      final configPath = await ConfigPaths.getDefaultConfigFilePath();
      await File(configPath).writeAsString(json.encode(_defaultConfig));
    } catch (e) {
      _logger.warning('Error saving default config: $e');
    }
  }
}
