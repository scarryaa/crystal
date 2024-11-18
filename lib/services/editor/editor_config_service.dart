import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crystal/models/editor/config/config_paths.dart';
import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

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
    'isTerminalVisible': false,
    'currentDirectory': '',
    'fileExplorerWidth': 170.0,
    'tabWidth': 4.0,
    'terminalHeight': 300.0,
  };

  EditorConfigService._() : themeService = EditorThemeService() {
    EditorLayoutService(
      horizontalPadding: 16.0,
      verticalPaddingLines: 2,
      gutterWidth: 60,
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

    try {
      // Ensure config directory exists first
      final configPath = await ConfigPaths.getConfigFilePath();
      final directory = Directory(path.dirname(configPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Initialize in sequence
      await service._ensureConfigDirectoryExists();
      await service.loadConfig();
      await service.saveDefaultConfig();

      // Add delay before watching
      await Future.delayed(const Duration(milliseconds: 100));
      await service._watchConfigFile();

      return service;
    } catch (e, stack) {
      service._logger.severe('Error creating EditorConfigService: $e\n$stack');
      if (!service._isLoaded) {
        await service._setDefaultConfig();
      }
      return service;
    }
  }

  @override
  void dispose() {
    try {
      _configFileWatcher?.cancel();
      _configFileWatcher = null;
    } catch (e) {
      _logger.warning('Error disposing config watcher: $e');
    }
    super.dispose();
  }

  Future<void> loadConfig() async {
    try {
      await _ensureConfigDirectoryExists();
      final configFile = File(await ConfigPaths.getConfigFilePath());

      if (!await configFile.exists()) {
        _logger.info('Config file not found, creating default');
        await _setDefaultConfig();
        return;
      }

      config = await _loadConfigFromFile(configFile);
      await _loadTheme();
      _isLoaded = true;
      notifyListeners();
    } catch (e, stack) {
      _logger.severe('Error loading config: $e\n$stack');
      if (!_isLoaded) {
        await _setDefaultConfig();
      }
    }
  }

  Future<void> _ensureConfigDirectoryExists() async {
    try {
      final configPath = await ConfigPaths.getConfigFilePath();
      final directory = Directory(path.dirname(configPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final configFile = File(configPath);
      if (!await configFile.exists()) {
        await configFile.writeAsString(json.encode(_defaultConfig));
      }
    } catch (e) {
      _logger.severe('Error creating config directory: $e');
    }
  }

  Future<void> _watchConfigFile() async {
    try {
      // Cancel existing watcher with delay
      if (_configFileWatcher != null) {
        await _configFileWatcher!.cancel();
        await Future.delayed(const Duration(milliseconds: 100));
        _configFileWatcher = null;
      }

      final configPath = await ConfigPaths.getConfigFilePath();
      final configFile = File(configPath);

      // Don't set up watcher in debug mode on macOS
      if (Platform.isMacOS &&
          const bool.fromEnvironment('dart.vm.product') == false) {
        _logger.info('Skipping file watcher setup in debug mode on macOS');
        return;
      }

      _configFileWatcher =
          configFile.watch(events: FileSystemEvent.modify).listen((event) {
        if (event.type == FileSystemEvent.modify) {
          Future.delayed(const Duration(milliseconds: 100), loadConfig);
        }
      });
    } catch (e) {
      _logger.warning('Error setting up file watcher: $e');
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
        isTerminalVisible: configData['isTerminalVisible'] as bool? ??
            _defaultConfig['isTerminalVisible'] as bool,
        currentDirectory: configData['currentDirectory'] as String? ??
            _defaultConfig['currentDirectory'] as String,
        tabWidth: (configData['tabWidth'] as num?)?.toDouble() ??
            _defaultConfig['tabWidth'] as double,
        terminalHeight: (configData['terminalHeight'] as num?)?.toDouble() ??
            _defaultConfig['terminalHeight'] as double,
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
      isTerminalVisible: _defaultConfig['isTerminalVisible'] as bool,
      currentDirectory: _defaultConfig['currentDirectory'] as String,
      tabWidth: _defaultConfig['tabWidth'] as double,
      terminalHeight: _defaultConfig['terminalHeight'] as double,
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
      final directory = Directory(path.dirname(configPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final configData = {
        'fontSize': config.fontSize,
        'uiFontSize': config.uiFontSize,
        'fontFamily': config.fontFamily,
        'uiFontFamily': config.uiFontFamily,
        'theme': themeService.currentTheme!.name,
        'whitespaceIndicatorRadius': config.whitespaceIndicatorRadius,
        'isFileExplorerVisible': config.isFileExplorerVisible,
        'isFileExplorerOnLeft': config.isFileExplorerOnLeft,
        'isTerminalVisible': config.isTerminalVisible,
        'currentDirectory': config.currentDirectory,
        'fileExplorerWidth': config.fileExplorerWidth,
        'tabWidth': config.tabWidth,
        'terminalHeight': config.terminalHeight,
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
