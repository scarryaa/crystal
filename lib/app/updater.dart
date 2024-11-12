import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:path/path.dart' as path;

final log = Logger('Updater');

class UpdateInfo {
  final bool hasUpdate;
  final String? version;
  final String? downloadUrl;

  UpdateInfo({
    required this.hasUpdate,
    this.version,
    this.downloadUrl,
  });
}

Future<void> performUpdate() async {
  try {
    log.info('Starting update process...');

    final installDir = await _getInstallDirectory();
    final updateInfo = await checkForUpdates('your-username/your-repo');

    if (!updateInfo.hasUpdate || updateInfo.downloadUrl == null) {
      log.info('No update available');
      return;
    }

    // Download new version
    final downloadedFile = await _downloadFile(updateInfo.downloadUrl!);

    // Backup current installation
    await _backupCurrentInstallation(installDir);

    try {
      if (Platform.isLinux) {
        await _updateAppImage(downloadedFile, installDir);
      } else {
        await _updateFromZip(downloadedFile, installDir);
      }

      // Clean up backup after successful update
      await _cleanupBackup(installDir);

      // Launch updated main app
      if (Platform.isMacOS) {
        await Process.run('open', ['-a', '$installDir/crystal.app']);
      } else if (Platform.isWindows) {
        await Process.run('$installDir/crystal.exe', [], runInShell: true);
      } else {
        await Process.run('$installDir/crystal.AppImage', []);
      }
    } catch (e) {
      log.severe('Update failed: $e');
      await _restoreBackup(installDir);
      rethrow;
    }
  } catch (e) {
    log.severe('Update process failed: $e');
    exit(1);
  }
}

Future<void> launchUpdater() async {
  final String appPath = Platform.resolvedExecutable;
  try {
    if (Platform.isMacOS) {
      await Process.run('open', ['-a', appPath, '--args', '--update']);
    } else if (Platform.isWindows) {
      await Process.run(appPath, ['--update'], runInShell: true);
    } else {
      await Process.run(appPath, ['--update']);
    }
    exit(0); // Exit main app to allow update
  } catch (e) {
    log.severe('Failed to launch updater: $e');
  }
}

Future<String> _getInstallDirectory() async {
  final String executablePath = Platform.resolvedExecutable;
  final String directory = Directory(executablePath).parent.path;

  if (Platform.isMacOS) {
    // For macOS, go up two levels from the executable
    return Directory(directory).parent.parent.path;
  } else if (Platform.isWindows) {
    // For Windows, use the executable's directory
    return directory;
  } else {
    // For Linux, use the AppImage directory
    return directory;
  }
}

Future<void> _backupCurrentInstallation(String installDir) async {
  try {
    final backupDir = Directory('${installDir}_backup');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }

    // Create backup directory
    await backupDir.create();

    // Copy all files from install directory to backup
    final files = Directory(installDir).listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        final relativePath = path.relative(file.path, from: installDir);
        final backupPath = path.join(backupDir.path, relativePath);
        await Directory(path.dirname(backupPath)).create(recursive: true);
        await file.copy(backupPath);
      }
    }
  } catch (e) {
    throw Exception('Failed to backup installation: $e');
  }
}

Future<void> _restoreBackup(String installDir) async {
  try {
    final backupDir = Directory('${installDir}_backup');
    if (!await backupDir.exists()) {
      throw Exception('Backup directory not found');
    }

    // Delete current installation
    await Directory(installDir).delete(recursive: true);
    await Directory(installDir).create();

    // Copy all files from backup to install directory
    final files = backupDir.listSync(recursive: true);
    for (final file in files) {
      if (file is File) {
        final relativePath = path.relative(file.path, from: backupDir.path);
        final installPath = path.join(installDir, relativePath);
        await Directory(path.dirname(installPath)).create(recursive: true);
        await file.copy(installPath);
      }
    }
  } catch (e) {
    throw Exception('Failed to restore backup: $e');
  }
}

Future<File> _downloadFile(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Failed to download file: ${response.statusCode}');
    }

    final tempDir = Directory.systemTemp;
    final tempFile =
        File('${tempDir.path}/update_${DateTime.now().millisecondsSinceEpoch}');
    await tempFile.writeAsBytes(response.bodyBytes);
    return tempFile;
  } catch (e) {
    throw Exception('Failed to download file: $e');
  }
}

Future<void> _updateFromZip(File zipFile, String installDir) async {
  try {
    log.info('Starting zip extraction to: $installDir');
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        log.fine('Extracting: $filename');
        final data = file.content as List<int>;
        final filePath = path.join(installDir, filename);
        await Directory(path.dirname(filePath)).create(recursive: true);
        await File(filePath).writeAsBytes(data);
      }
    }
    log.info('Zip extraction completed');
  } catch (e) {
    log.severe('Failed to extract zip: $e');
    throw Exception('Failed to extract zip: $e');
  }
}

Future<String> _getCurrentVersion() async {
  try {
    final String executableDir =
        Directory(Platform.resolvedExecutable).parent.path;
    final File versionFile = File(path.join(executableDir, 'version.txt'));

    if (await versionFile.exists()) {
      return (await versionFile.readAsString()).trim();
    }
    // Default version if file doesn't exist
    return 'v1.0.0';
  } catch (e) {
    log.severe('Failed to get current version: $e');
    return 'v1.0.0';
  }
}

Future<UpdateInfo> checkForUpdates(String repo) async {
  try {
    final versionResponse = await http.get(
        Uri.parse('https://raw.githubusercontent.com/$repo/main/version.json'));

    if (versionResponse.statusCode != 200) {
      throw Exception('Failed to fetch version info');
    }

    final versionData = jsonDecode(versionResponse.body);
    final currentVersion = await _getCurrentVersion();
    final latestVersion = versionData['version'];

    if (latestVersion != currentVersion) {
      return UpdateInfo(
        hasUpdate: true,
        version: latestVersion,
        downloadUrl: _getAssetUrl(repo, versionData['assets']),
      );
    }

    return UpdateInfo(hasUpdate: false);
  } catch (e) {
    log.severe('Failed to check for updates: $e');
    return UpdateInfo(hasUpdate: false);
  }
}

String _getAssetUrl(String repo, Map<String, dynamic> assets) {
  final platform = Platform.isMacOS
      ? 'macos'
      : Platform.isWindows
          ? 'windows'
          : 'linux';

  final assetName = assets[platform];
  return 'https://github.com/$repo/releases/latest/download/$assetName';
}

Future<void> _cleanupBackup(String installDir) async {
  try {
    final backupDir = Directory('${installDir}_backup');
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
      log.info('Backup cleaned up successfully');
    }
  } catch (e) {
    log.warning('Failed to cleanup backup: $e');
  }
}

Future<void> _updateAppImage(File newAppImage, String installDir) async {
  try {
    final targetPath = path.join(installDir, 'app.AppImage');

    // Make new AppImage executable
    await Process.run('chmod', ['+x', newAppImage.path]);

    // Copy new AppImage to installation directory
    await newAppImage.copy(targetPath);

    // Make installed AppImage executable
    await Process.run('chmod', ['+x', targetPath]);
  } catch (e) {
    throw Exception('Failed to update AppImage: $e');
  }
}

Future<void> updateFromGithub(String repo, String tag) async {
  final installDir = Platform.resolvedExecutable;
  final directory = Directory(installDir).parent.path;

  try {
    // Get the latest release info
    final releaseResponse = await http
        .get(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));

    if (releaseResponse.statusCode != 200) {
      throw Exception(
          'Failed to fetch release info: ${releaseResponse.statusCode}');
    }

    final releaseData = jsonDecode(releaseResponse.body);
    final assets = releaseData['assets'] as List;

    // Get correct asset based on platform
    final assetName = Platform.isMacOS
        ? 'crystal-mac.zip'
        : Platform.isWindows
            ? 'crystal-windows.zip'
            : 'crystal-linux.AppImage';

    final asset = assets.firstWhere(
      (a) => a['name'] == assetName,
      orElse: () => throw Exception('Asset not found: $assetName'),
    );

    // Download the update
    final downloadUrl = asset['browser_download_url'];
    final downloadedFile = await _downloadFile(downloadUrl);

    log.info('Downloading update from: $downloadUrl');

    // Backup current installation
    await _backupCurrentInstallation(directory);

    try {
      // Update based on platform
      if (Platform.isLinux) {
        await _updateAppImage(downloadedFile, directory);
      } else {
        await _updateFromZip(downloadedFile, directory);
      }
    } catch (e) {
      // Restore backup if update fails
      await _restoreBackup(directory);
      rethrow;
    } finally {
      // Cleanup
      await downloadedFile.delete();
    }
  } catch (e) {
    throw Exception('Update failed: $e');
  }
}

Future<void> launchApp() async {
  try {
    final String executablePath = Platform.resolvedExecutable;

    if (Platform.isMacOS) {
      await Process.run('open', ['-a', executablePath]);
    } else if (Platform.isWindows) {
      await Process.run(executablePath, [], runInShell: true);
    } else if (Platform.isLinux) {
      await Process.run('chmod', ['+x', executablePath]);
      await Process.run(executablePath, []);
    }
  } catch (e) {
    log.severe('Failed to launch app: $e');
  }
}
