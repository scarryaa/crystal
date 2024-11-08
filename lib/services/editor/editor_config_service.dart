import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';

class EditorConfigService extends ChangeNotifier {
  final EditorThemeService themeService;
  late final EditorConfig config;
  final _logger = Logger('EditorConfigService');

  static const Map<String, dynamic> _defaultConfig = {
    'fontSize': 14.0,
    'fontFamily': 'IBM Plex Mono',
    'whitespaceIndicatorRadius': 1.0,
    'theme': 'default-dark',
  };

  EditorConfigService._() : themeService = EditorThemeService();

  static Future<EditorConfigService> create() async {
    final service = EditorConfigService._();
    await service._loadConfig();
    await service.saveDefaultConfig();
    return service;
  }

  Future<void> _loadConfig() async {
    try {
      final configFile = File(await ConfigPaths.getConfigFilePath());
      config = await _loadConfigFromFile(configFile);
      await _loadTheme();
    } catch (e) {
      _logger.warning('Error loading config: $e');
      await _setDefaultConfig();
    }
  }

  Future<EditorConfig> _loadConfigFromFile(File configFile) async {
    if (!await configFile.exists()) {
      return _createDefaultConfig();
    }

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
    );
  }

  Future<EditorConfig> _createDefaultConfig() async {
    final defaultConfig = EditorConfig(
      fontSize: _defaultConfig['fontSize'] as double,
      fontFamily: _defaultConfig['fontFamily'] as String,
      whitespaceIndicatorRadius:
          _defaultConfig['whitespaceIndicatorRadius'] as double,
    );
    config = defaultConfig;
    await saveConfig();
    return defaultConfig;
  }

  Future<void> _loadTheme() async {
    await themeService.loadThemeFromJson(_defaultConfig['theme'] as String);
  }

  Future<void> _setDefaultConfig() async {
    config = EditorConfig(
      fontSize: _defaultConfig['fontSize'] as double,
      fontFamily: _defaultConfig['fontFamily'] as String,
      whitespaceIndicatorRadius:
          _defaultConfig['whitespaceIndicatorRadius'] as double,
    );
    await themeService.loadThemeFromJson(_defaultConfig['theme'] as String);
  }

  Future<void> saveConfig() async {
    try {
      final configPath = await ConfigPaths.getConfigFilePath();
      final configData = {
        'fontSize': config.fontSize,
        'fontFamily': config.fontFamily,
        'theme': themeService.currentTheme!.name,
        'whitespaceIndicatorRadius': config.whitespaceIndicatorRadius,
      };

      await File(configPath).writeAsString(json.encode(configData));
    } catch (e) {
      _logger.warning('Error saving config: $e');
    }
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
