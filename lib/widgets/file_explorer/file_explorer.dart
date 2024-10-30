import 'dart:io';
import 'package:crystal/widgets/file_explorer/file_item.dart';
import 'package:flutter/material.dart';

class FileExplorer extends StatefulWidget {
  final String rootDir;
  final Function(String path) tapCallback;

  const FileExplorer({
    super.key,
    required this.rootDir,
    required this.tapCallback,
  });

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  late Future<List<FileSystemEntity>> _filesFuture;
  Map<String, bool> expandedDirs = {};

  @override
  void initState() {
    super.initState();
    _filesFuture = _enumerateFiles(widget.rootDir);
  }

  Future<List<FileSystemEntity>> _enumerateFiles(String directory) async {
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

  Widget _buildFileTree(FileSystemEntity entity, int depth) {
    final fileName = entity.path.split(Platform.pathSeparator).last;
    final isDirectory = entity is Directory;
    final isExpanded = expandedDirs[entity.path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FileItem(
          fileName: fileName,
          isDirectory: isDirectory,
          expanded: isExpanded,
          level: depth,
          onTap: () {
            if (isDirectory) {
              setState(() {
                expandedDirs[entity.path] = !isExpanded;
              });
            } else {
              widget.tapCallback(entity.path);
            }
          },
        ),
        if (isDirectory && isExpanded)
          FutureBuilder<List<FileSystemEntity>>(
            future: _enumerateFiles(entity.path),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: snapshot.data!
                    .map((e) => _buildFileTree(e, depth + 1))
                    .toList(),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: Colors.grey[400]!),
          ),
        ),
        child: Container(
          color: Colors.white,
          height: double.infinity,
          child: SizedBox(
            width: 150,
            child: FutureBuilder<List<FileSystemEntity>>(
              future: _filesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text(
                      'No files found',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...snapshot.data!
                          .map((entity) => _buildFileTree(entity, 0)),
                      const SizedBox(height: 18),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
