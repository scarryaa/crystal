// ignore_for_file: avoid_print

import 'package:crystal/utils/version_manager.dart';

void main(List<String> args) async {
  if (args.isEmpty) {
    print('Please provide a version number (e.g. 1.0.0)');
    return;
  }

  final newVersion = args[0];
  try {
    await VersionManager.updateVersion(newVersion);
    print('Successfully updated version to $newVersion');
  } catch (e) {
    print('Failed to update version: $e');
  }
}
