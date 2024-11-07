import 'dart:io';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/widgets/file_explorer/file_explorer_action_bar.dart';
import 'package:crystal/widgets/file_explorer/file_item.dart';
import 'package:crystal/widgets/file_explorer/indent_painter.dart';
import 'package:flutter/material.dart';

class FileExplorer extends StatefulWidget {
  final String rootDir;
  final Function(String path) tapCallback;
  final EditorConfigService editorConfigService;

  const FileExplorer({
    super.key,
    required this.rootDir,
    required this.tapCallback,
    required this.editorConfigService,
  });

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  late Future<List<FileSystemEntity>> _filesFuture;
  Map<String, bool> expandedDirs = {};
  double width = 150;

  @override
  void initState() {
    super.initState();
    _filesFuture = _enumerateFiles(widget.rootDir);
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
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

  Future<void> _expandAllRecursively(List<FileSystemEntity> entities) async {
    for (var entity in entities) {
      if (entity is Directory) {
        expandedDirs[entity.path] = true;
        final subEntities = await _enumerateFiles(entity.path);
        await _expandAllRecursively(subEntities);
      }
    }
  }

  Widget _buildFileTree(FileSystemEntity entity, int depth) {
    final fileName = entity.path.split(Platform.pathSeparator).last;
    final isDirectory = entity is Directory;
    final isExpanded = expandedDirs[entity.path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: IndentPainter(level: depth),
          child: FileItem(
            highlightColor:
                widget.editorConfigService.themeService.currentTheme != null
                    ? widget
                        .editorConfigService.themeService.currentTheme!.primary
                    : Colors.blue,
            textColor:
                widget.editorConfigService.themeService.currentTheme != null
                    ? widget.editorConfigService.themeService.currentTheme!.text
                    : Colors.black,
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
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                border: Border(
                    right: BorderSide(
                        color: widget.editorConfigService.themeService
                                    .currentTheme !=
                                null
                            ? widget.editorConfigService.themeService
                                .currentTheme!.border
                            : Colors.grey[400]!))),
            child: Container(
              color:
                  widget.editorConfigService.themeService.currentTheme != null
                      ? widget.editorConfigService.themeService.currentTheme!
                          .background
                      : Colors.white,
              height: double.infinity,
              width: width,
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

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FileExplorerActionBar(
                        textColor: widget.editorConfigService.themeService
                                    .currentTheme !=
                                null
                            ? widget.editorConfigService.themeService
                                .currentTheme!.text
                            : Colors.black,
                        onRefresh: () {
                          setState(() {
                            _filesFuture = _enumerateFiles(widget.rootDir);
                          });
                        },
                        onExpandAll: () async {
                          await _expandAllRecursively(snapshot.data!);
                          setState(() {});
                        },
                        onCollapseAll: () {
                          setState(() {
                            expandedDirs.clear();
                          });
                        },
                      ),
                      Expanded(
                        child: ScrollbarTheme(
                          data: ScrollbarThemeData(
                            thickness: WidgetStateProperty.all(8.0),
                            radius: const Radius.circular(0),
                            thumbColor: WidgetStateProperty.all(widget
                                        .editorConfigService
                                        .themeService
                                        .currentTheme !=
                                    null
                                ? widget.editorConfigService.themeService
                                    .currentTheme!.border
                                : Colors.grey[400]),
                          ),
                          child: Scrollbar(
                            controller: _horizontalController,
                            thickness: 8,
                            notificationPredicate: (notification) =>
                                notification.depth == 1,
                            child: Scrollbar(
                              controller: _verticalController,
                              thickness: 8,
                              child: SingleChildScrollView(
                                controller: _verticalController,
                                child: SingleChildScrollView(
                                  controller: _horizontalController,
                                  scrollDirection: Axis.horizontal,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      ...snapshot.data!.map((entity) =>
                                          _buildFileTree(entity, 0)),
                                      const SizedBox(height: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  width = (width + details.delta.dx)
                      .clamp(150.0, MediaQuery.of(context).size.width - 200);
                });
              },
              child: Container(
                width: 1.5,
                height: double.infinity,
                color:
                    widget.editorConfigService.themeService.currentTheme != null
                        ? widget.editorConfigService.themeService.currentTheme!
                            .border
                        : Colors.transparent,
              ),
            ),
          )
        ],
      ),
    );
  }
}
