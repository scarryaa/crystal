import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class ConfigPaths {
  static Future<String> getConfigDir() async {
    if (Platform.isWindows) {
      // Windows: %APPDATA%\
      final appData = Platform.environment['APPDATA'];
      return path.join(appData!, 'crystal');
    } else if (Platform.isMacOS) {
      // macOS: ~/Library/Application Support/
      final support = await getApplicationSupportDirectory();
      return path.join(support.path, 'crystal');
    } else if (Platform.isLinux) {
      // Linux: ~/.config/
      final home = Platform.environment['HOME'];
      return path.join(home!, '.config', 'crystal');
    }

    throw UnsupportedError('Unsupported platform');
  }

  static Future<String> getConfigFilePath() async {
    final configDir = await getConfigDir();
    // Create directory if it doesn't exist
    await Directory(configDir).create(recursive: true);
    return path.join(configDir, 'editor_config.json');
  }
}
