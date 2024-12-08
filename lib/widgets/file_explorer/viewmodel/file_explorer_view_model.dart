import 'dart:io';
import 'package:crystal/models/file_explorer/file_item.dart';
import 'package:flutter/material.dart';

class FileExplorerViewModel extends ChangeNotifier {
  final List<FileItem> items = [];
  late final String currentPath;
  final double width = 200;

  FileExplorerViewModel({String? initialPath}) {
    currentPath = initialPath ?? Directory.current.path;
  }

  Future<void> populateItems() async {
    try {
      items.clear();

      final directory = Directory(currentPath);
      final entities = await directory.list(recursive: false).toList();

      // Sort by directory first, then by name
      entities.sort((a, b) {
        final aIsDirectory =
            a.statSync().type == FileSystemEntityType.directory;
        final bIsDirectory =
            b.statSync().type == FileSystemEntityType.directory;

        // If both are directories or both are files, sort by name
        if (aIsDirectory == bIsDirectory) {
          final aName = a.path.split(Platform.pathSeparator).last;
          final bName = b.path.split(Platform.pathSeparator).last;
          return aName.toLowerCase().compareTo(bName.toLowerCase());
        }

        return aIsDirectory ? -1 : 1;
      });

      for (final entity in entities) {
        final stat = await entity.stat();
        items.add(FileItem(
          name: entity.path.split(Platform.pathSeparator).last,
          isDirectory: stat.type == FileSystemEntityType.directory,
          path: entity.path,
        ));
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error populating items: $e');
    }
  }
}
