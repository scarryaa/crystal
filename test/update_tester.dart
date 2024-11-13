// ignore_for_file: avoid_print

import 'dart:io';
import 'package:crystal/app/test_updater.dart';
import 'package:crystal/app/updater.dart';

void main() async {
  print('Starting update test...');

  try {
    await testUpdate();
    print('Update test completed successfully!');
  } catch (e) {
    print('Update test failed: $e');
  }
}

Future<void> testUpdate() async {
  final testDir = Directory('test_install');
  final testBackupDir = Directory('test_install_backup');

  try {
    print('Creating test directories...');
    await testDir.create(recursive: true);

    print('Copying current build...');
    await copyCurrentBuildToTest(testDir.path);

    print('Creating mock update...');
    final mockUpdate = await createMockUpdate();

    print('Testing backup process...');
    await backupCurrentInstallation(testDir.path);

    print('Testing update process...');
    await updateFromZip(mockUpdate, testDir.path);

    print('Verifying update...');
    await verifyUpdate(testDir.path);
  } finally {
    print('Cleaning up test directories...');
    if (await testDir.exists()) await testDir.delete(recursive: true);
    if (await testBackupDir.exists()) {
      await testBackupDir.delete(recursive: true);
    }
  }
}
