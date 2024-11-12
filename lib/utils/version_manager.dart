import 'dart:io';
import 'package:path/path.dart' as path;

class VersionManager {
  static Future<void> updateVersion(String newVersion) async {
    // Remove 'v' prefix if present
    newVersion = newVersion.replaceFirst('v', '');

    final projectRoot = Directory.current.path;

    // Update version.txt
    await File(path.join(projectRoot, 'version.txt'))
        .writeAsString('v$newVersion');

    // Update pubspec.yaml
    final pubspecFile = File(path.join(projectRoot, 'pubspec.yaml'));
    var content = await pubspecFile.readAsString();

    content = content.replaceFirst(
        RegExp(r'version:\s*[^\s]+'), 'version: $newVersion');
    await pubspecFile.writeAsString(content);

    // Update GitHub workflow
    final workflowFile =
        File(path.join(projectRoot, '.github/workflows/flutter_desktop.yml'));

    if (await workflowFile.exists()) {
      var workflowContent = await workflowFile.readAsString();
      workflowContent = workflowContent.replaceFirst(
          RegExp(r'APP_VERSION:\s*[^\s]+'), 'APP_VERSION: v$newVersion');
      await workflowFile.writeAsString(workflowContent);
    }
  }

  static Future<String> getCurrentVersion() async {
    final versionFile = File(path.join(Directory.current.path, 'version.txt'));
    if (await versionFile.exists()) {
      return (await versionFile.readAsString()).trim();
    }
    return 'v0.0.0';
  }
}
