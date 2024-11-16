import 'dart:convert';
import 'dart:io';

import 'package:crystal/services/editor/editor_config_service.dart';

class FileService {
  final EditorConfigService configService;
  String rootDirectory = '';
  late Future<List<FileSystemEntity>> filesFuture;

  FileService({required this.configService}) {
    rootDirectory = configService.config.currentDirectory ?? '';
    filesFuture = enumerateFiles(rootDirectory);
  }

  Future<bool> isUtf8File(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return false;

      // Read first few KB of the file to check encoding
      final bytes = await file.openRead(0, 8192).first;

      // Try to decode as UTF-8
      try {
        utf8.decode(bytes, allowMalformed: false);
        return true;
      } on FormatException {
        return false;
      }
    } catch (e) {
      return false;
    }
  }

  Future<List<FileSystemEntity>> enumerateFiles(String directory) async {
    if (directory.isEmpty) {
      return [];
    }

    final dir = Directory(directory);
    try {
      final entities = await dir.list().toList();
      entities.sort((a, b) {
        final aIsDir = a is Directory;
        final bIsDir = b is Directory;
        if (aIsDir && !bIsDir) return -1;
        if (!aIsDir && bIsDir) return 1;
        return a.path.compareTo(b.path);
      });
      return entities;
    } catch (e) {
      return [];
    }
  }

  void refresh() {
    filesFuture = enumerateFiles(rootDirectory);
  }

  void setRootDirectory(String directory) {
    rootDirectory = directory;
    refresh();
  }

  static void saveFile(String path, String content) {
    File file = File(path);
    file.writeAsStringSync(content);
  }

  static String readFile(String path) {
    File file = File(path);
    return file.readAsStringSync();
  }

  String getRelativePath(String fullPath, String rootDir) {
    if (!fullPath.startsWith(rootDir)) {
      return fullPath;
    }

    String relativePath = fullPath.substring(rootDir.length);
    if (relativePath.startsWith(Platform.pathSeparator)) {
      relativePath = relativePath.substring(1);
    }

    return relativePath;
  }
}
