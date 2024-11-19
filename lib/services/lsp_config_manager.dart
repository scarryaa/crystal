import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class LSPConfigManager {
  static const int currentConfigVersion = 2;

  static final Map<String, String> _extensionToLanguageMap = {};

  static Future<void> _initializeExtensionMap() async {
    if (_extensionToLanguageMap.isNotEmpty) return;

    for (var entry in defaultConfigs.entries) {
      final languageName = entry.key;
      final extensions = List<String>.from(entry.value['extensions'] ?? []);
      for (var ext in extensions) {
        _extensionToLanguageMap[ext] = languageName;
      }
    }

    // Check for user-defined configs
    final configDirectory = await configDir;
    final dir = Directory(configDirectory);

    if (await dir.exists()) {
      await for (final file in dir.list(followLinks: false)) {
        if (file is File && file.path.endsWith('.json')) {
          try {
            final content = await file.readAsString();
            final config = jsonDecode(content) as Map<String, dynamic>;
            final languageName = p.basenameWithoutExtension(file.path);
            final extensions = List<String>.from(config['extensions'] ?? []);
            for (var ext in extensions) {
              _extensionToLanguageMap[ext] = languageName;
            }
          } catch (e) {
            print('Error reading config file ${file.path}: $e');
          }
        }
      }
    }
  }

  static Future<String?> getLanguageForExtension(String extension) async {
    await _initializeExtensionMap();

    // Normalize the extension to include the dot if not present
    final normalizedExtension =
        extension.startsWith('.') ? extension : '.$extension';

    return _extensionToLanguageMap[normalizedExtension];
  }

  static Map<String, Map<String, dynamic>> get defaultConfigs {
    final configs = {
      'dart': {
        'extensions': ['.dart'],
        'executable': 'dart',
        'args': ['language-server', '--protocol=lsp'],
        'version': currentConfigVersion
      },
      'python': {
        'extensions': ['.py'],
        'executable': 'pylsp',
        'args': [],
        'version': currentConfigVersion
      },
      'typescript': {
        'extensions': ['.js', '.ts', '.tsx', '.jsx'],
        'executable': 'typescript-language-server',
        'args': ['--stdio'],
        'version': currentConfigVersion
      },
      'java': {
        'extensions': ['.java'],
        'executable': 'jdtls',
        'args': [],
        'version': currentConfigVersion
      },
      'go': {
        'extensions': ['.go'],
        'executable': 'gopls',
        'args': ['serve'],
        'version': currentConfigVersion
      },
      'rust': {
        'extensions': ['.rs'],
        'executable': 'rust-analyzer',
        'args': [],
        'version': currentConfigVersion
      },
      'cpp': {
        'extensions': ['.cpp', '.c'],
        'executable': 'clangd',
        'args': [],
        'version': currentConfigVersion
      },
      'csharp': {
        'extensions': ['.cs'],
        'executable': 'omnisharp',
        'args': ['-lsp'],
        'version': currentConfigVersion
      },
      'php': {
        'extensions': ['.php'],
        'executable': 'intelephense',
        'args': ['--stdio'],
        'version': currentConfigVersion
      },
      'ruby': {
        'extensions': ['.rb'],
        'executable': 'solargraph',
        'args': ['stdio'],
        'version': currentConfigVersion
      },
      'lua': {
        'extensions': ['.lua'],
        'executable': 'lua-language-server',
        'args': [],
        'version': currentConfigVersion
      },
      'vue': {
        'extensions': ['.vue'],
        'executable': 'vls',
        'args': [],
        'version': currentConfigVersion
      },
      'swift': {
        'extensions': ['.swift'],
        'executable': 'sourcekit-lsp',
        'args': [],
        'version': currentConfigVersion
      },
      'kotlin': {
        'extensions': ['.kt'],
        'executable': 'kotlin-language-server',
        'args': [],
        'version': currentConfigVersion
      },
      'html': {
        'extensions': ['.html'],
        'executable': 'html-languageserver',
        'args': ['--stdio'],
        'version': currentConfigVersion
      },
      'css': {
        'extensions': ['.css'],
        'executable': 'css-languageserver',
        'args': ['--stdio'],
        'version': currentConfigVersion
      },
      'yaml': {
        'extensions': ['.yaml'],
        'executable': 'yaml-language-server',
        'args': ['--stdio'],
        'version': currentConfigVersion
      },
      'json': {
        'extensions': ['.json'],
        'executable': 'vscode-json-language-server',
        'args': ['--stdio'],
        'version': currentConfigVersion,
        'initializationOptions': {
          'provideFormatter': true,
        },
      },
    };

    for (var config in configs.values) {
      config['version'] = currentConfigVersion;
    }

    return configs;
  }

  static Map<String, dynamic> _mergeConfigs(
    Map<String, dynamic> defaultConfig,
    Map<String, dynamic> userConfig,
  ) {
    final mergedConfig = Map<String, dynamic>.from(defaultConfig);

    // Preserve user customizations for existing keys
    for (var entry in userConfig.entries) {
      if (entry.key != 'version') {
        // Don't preserve old version
        mergedConfig[entry.key] = entry.value;
      }
    }

    return mergedConfig;
  }

  static Future<void> createOrUpdateConfigs() async {
    final configDirectory = await configDir;

    for (var entry in defaultConfigs.entries) {
      final languageName = entry.key;
      final defaultConfig = entry.value;
      final configFile = File(p.join(configDirectory, '$languageName.json'));

      print(configFile);
      if (await configFile.exists()) {
        // Read existing config
        final content = await configFile.readAsString();
        final userConfig = jsonDecode(content) as Map<String, dynamic>;

        // Check if update is needed
        final userVersion = userConfig['version'] as int? ?? 0;
        if (userVersion < currentConfigVersion) {
          // Merge configurations and update file
          final mergedConfig = _mergeConfigs(defaultConfig, userConfig);
          await configFile.writeAsString(jsonEncode(mergedConfig));
        }
      } else {
        // Create new config file
        await configFile.writeAsString(jsonEncode(defaultConfig));
      }
    }
  }

  static Future<int> getConfigVersion(String languageName) async {
    final configDirectory = await configDir;
    final configFile = File(p.join(configDirectory, '$languageName.json'));

    if (await configFile.exists()) {
      final content = await configFile.readAsString();
      final config = jsonDecode(content) as Map<String, dynamic>;
      return config['version'] as int? ?? 0;
    }
    return 0;
  }

  static Future<String> get configDir async {
    final baseDir = await _getConfigDirectory();
    final serversDir = Directory(p.join(baseDir.path, 'servers'));
    if (!await serversDir.exists()) {
      await serversDir.create(recursive: true);
    }
    return serversDir.path;
  }

  static Future<Directory> _getConfigDirectory() async {
    Directory configDir;
    if (Platform.isWindows) {
      configDir =
          Directory(p.join(Platform.environment['APPDATA']!, 'crystal'));
    } else if (Platform.isMacOS) {
      configDir = Directory(p.join(Platform.environment['HOME']!, 'Library',
          'Application Support', 'crystal'));
    } else {
      configDir = Directory(
          p.join(Platform.environment['HOME']!, '.config', 'crystal'));
    }

    if (!await configDir.exists()) {
      await configDir.create(recursive: true);
    }
    return configDir;
  }

  static Future<void> createDefaultConfigs() async {
    final configDirectory = await configDir;

    for (var entry in defaultConfigs.entries) {
      final languageName = entry.key;
      final config = entry.value;

      final configFile = File(p.join(configDirectory, '$languageName.json'));
      if (!await configFile.exists()) {
        await configFile.writeAsString(jsonEncode(config));
      }
    }
  }

  static Future<Map<String, dynamic>?> getLanguageConfig(
      String extension) async {
    // Normalize the extension to include the dot if not present
    final normalizedExtension =
        extension.startsWith('.') ? extension : '.$extension';

    try {
      // First check user configs
      final configDirectory = await configDir;
      final dir = Directory(configDirectory);

      if (await dir.exists()) {
        await for (final file in dir.list(followLinks: false)) {
          if (file is File && file.path.endsWith('.json')) {
            try {
              final content = await file.readAsString();
              final config = jsonDecode(content) as Map<String, dynamic>;

              final extensions = List<String>.from(config['extensions'] ?? []);
              if (extensions.contains(normalizedExtension)) {
                // Add the language name to the config
                final languageName = p.basenameWithoutExtension(file.path);
                return {
                  ...config,
                  'language': languageName,
                  'configPath': file.path,
                };
              }
            } catch (e) {
              print('Error reading config file ${file.path}: $e');
              continue; // Skip this file if there's an error
            }
          }
        }
      }

      // If no user config found, check default configs
      for (final entry in defaultConfigs.entries) {
        final extensions = List<String>.from(entry.value['extensions'] ?? []);
        if (extensions.contains(normalizedExtension)) {
          return {
            ...entry.value,
            'language': entry.key,
            'isDefault': true,
          };
        }
      }
    } catch (e) {
      print('Error searching language config for $extension: $e');
    }

    return null;
  }

  static Future<void> addOrUpdateLanguageConfig(
      String languageName, Map<String, dynamic> config) async {
    final configDirectory = await configDir;
    final configFile = File(p.join(configDirectory, '$languageName.json'));
    await configFile.writeAsString(jsonEncode(config));
  }
}
