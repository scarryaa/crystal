import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crystal/app/updater.dart';
import 'package:path/path.dart' as path;

Future<void> testUpdate() async {
  final testDir = Directory('test_install');
  final testBackupDir = Directory('test_install_backup');

  try {
    // Create test installation directory
    await testDir.create();

    // Copy current build to test directory
    await copyCurrentBuildToTest(testDir.path);

    // Create mock update file
    final mockUpdate = await createMockUpdate();

    // Test update process
    await backupCurrentInstallation(testDir.path);
    await updateFromZip(mockUpdate, testDir.path);

    // Verify update
    await verifyUpdate(testDir.path);
  } finally {
    // Cleanup
    if (await testDir.exists()) await testDir.delete(recursive: true);
    if (await testBackupDir.exists()) {
      await testBackupDir.delete(recursive: true);
    }
  }
}

Future<void> copyCurrentBuildToTest(String testDir) async {
  final currentDir = Directory(Platform.resolvedExecutable).parent;
  await for (final entity in currentDir.list(recursive: true)) {
    if (entity is File) {
      final relativePath = path.relative(entity.path, from: currentDir.path);
      final targetPath = path.join(testDir, relativePath);
      await Directory(path.dirname(targetPath)).create(recursive: true);
      await entity.copy(targetPath);
    }
  }
}

Future<File> createMockUpdate() async {
  final tempDir = Directory.systemTemp;
  final archive = Archive();

  // Add mock files to archive
  archive.addFile(
      ArchiveFile('version.txt', 'v999.0.0'.length, utf8.encode('v999.0.0')));

  // Create mock executable
  final mockExe = Platform.isWindows ? 'crystal.exe' : 'crystal';
  archive.addFile(ArchiveFile(mockExe, 10, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]));

  // Write zip file
  final zipFile = File('${tempDir.path}/mock_update.zip');
  await zipFile.writeAsBytes(ZipEncoder().encode(archive)!);
  return zipFile;
}

Future<void> verifyUpdate(String testDir) async {
  final versionFile = File(path.join(testDir, 'version.txt'));
  if (!await versionFile.exists()) {
    throw Exception('Update verification failed: version.txt not found');
  }

  final version = await versionFile.readAsString();
  if (version.trim() != 'v999.0.0') {
    throw Exception('Update verification failed: incorrect version');
  }
}
