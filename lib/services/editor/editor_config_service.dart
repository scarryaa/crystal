import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';
import 'package:flutter/material.dart';

class EditorConfigService extends ChangeNotifier {
  final EditorThemeService themeService;
  late final EditorConfig config;

  EditorConfigService() : themeService = EditorThemeService() {
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final configPath = await ConfigPaths.getConfigFilePath();
      final configFile = File(configPath);

      if (await configFile.exists()) {
        // Load from existing config file
        final jsonString = await configFile.readAsString();
        final configData = json.decode(jsonString);

        config = EditorConfig(
          fontSize: configData['fontSize']?.toDouble() ?? 14.0,
          fontFamily: configData['fontFamily'] ?? 'IBM Plex Mono',
          whitespaceIndicatorRadius:
              configData['whitespaceIndicatorRadius']?.toDouble() ?? 1.0,
        );

        await themeService
            .loadThemeFromJson(configData['theme'] ?? 'default-dark');
      } else {
        // Create default config
        config = EditorConfig(
          fontSize: 14.0,
          fontFamily: 'IBM Plex Mono',
          whitespaceIndicatorRadius: 1.0,
        );

        await themeService.loadThemeFromJson('default-dark');

        // Save default config
        await saveConfig();
      }
    } catch (e) {
      print('Error loading config: $e');
      // Fallback to defaults
      config = EditorConfig(
        fontSize: 14.0,
        fontFamily: 'IBM Plex Mono',
        whitespaceIndicatorRadius: 1.0,
      );
      await themeService.loadThemeFromJson('default-dark');
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
      };

      final file = File(configPath);
      await file.writeAsString(json.encode(configData));
    } catch (e) {
      print('Error saving config: $e');
    }
  }
}
