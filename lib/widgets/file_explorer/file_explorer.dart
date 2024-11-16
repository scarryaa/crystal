import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/widgets/file_explorer/file_explorer_action_bar.dart';
import 'package:crystal/widgets/file_explorer/file_item.dart';
import 'package:crystal/widgets/file_explorer/indent_painter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:watcher/watcher.dart';

class FileExplorer extends StatefulWidget {
  final FileService fileService;
  final Function(String path) tapCallback;
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final GitService gitService;

  const FileExplorer(
      {super.key,
      required this.fileService,
      required this.tapCallback,
      required this.editorConfigService,
      required this.onDirectoryChanged,
      required this.gitService});

  @override
  State<FileExplorer> createState() => _FileExplorerState();
}

class _FileExplorerState extends State<FileExplorer> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  Map<String, FileStatus> _fileStatuses = {};
  Map<String, bool> expandedDirs = {};
  String? currentDirectory;
  double width = 150;
  StreamSubscription? _gitStatusSubscription;
  DirectoryWatcher? _directoryWatcher;
  StreamSubscription? _watcherSubscription;

  bool _hasModifiedChildren(String dirPath, Map<String, FileStatus> statuses) {
    return statuses.entries.any((entry) {
      final filePath = entry.key;
      return filePath.startsWith(dirPath) &&
          entry.value != FileStatus.unmodified;
    });
  }

  Future<void> _initializeGit() async {
    await widget.gitService.initialize(widget.fileService.rootDirectory);
  }

  Future<void> _initializeWatcher() async {
    await _watcherSubscription?.cancel();
    await _directoryWatcher?.ready;

    if (widget.fileService.rootDirectory.isNotEmpty) {
      _directoryWatcher = DirectoryWatcher(widget.fileService.rootDirectory);
      _watcherSubscription =
          _directoryWatcher!.events.listen((WatchEvent event) {
        // Debounce the updates to prevent rapid consecutive refreshes
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {
              widget.fileService.filesFuture = widget.fileService
                  .enumerateFiles(widget.fileService.rootDirectory);
              _updateFileStatuses();
            });
          }
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    width = max(widget.editorConfigService.config.uiFontSize * 11.0, 170.0);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeGit();
      await _updateFileStatuses();
      await _initializeWatcher();
    });

    _gitStatusSubscription = widget.gitService.onGitStatusChanged.listen((_) {
      _updateFileStatuses();
    });
  }

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _gitStatusSubscription?.cancel();
    _watcherSubscription?.cancel();
    super.dispose();
  }

  Future<void> _updateFileStatuses() async {
    _fileStatuses = await widget.gitService.getAllFileStatuses();
    setState(() {});
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

  Future<void> _createNewFolder() async {
    final controller = TextEditingController();

    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Folder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Folder Name',
            hintText: 'Enter folder name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (folderName != null && folderName.isNotEmpty) {
      final newDir =
          Directory('${widget.fileService.rootDirectory}/$folderName');
      await newDir.create();
      setState(() {
        widget.fileService.filesFuture =
            widget.fileService.enumerateFiles(widget.fileService.rootDirectory);
      });
    }
  }

  Future<void> _createNewFile() async {
    final controller = TextEditingController();

    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New File'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'File Name',
            hintText: 'Enter file name',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (fileName != null && fileName.isNotEmpty) {
      final newFile = File('${widget.fileService.rootDirectory}/$fileName');
      await newFile.create();
      setState(() {
        widget.fileService.filesFuture =
            widget.fileService.enumerateFiles(widget.fileService.rootDirectory);
      });
    }
  }

  Future<void> _handleDirectoryChanged(String newDirectory) async {
    setState(() {
      Directory.current = newDirectory;
      currentDirectory = newDirectory;
    });

    await _initializeWatcher();

    if (widget.onDirectoryChanged != null) {
      widget.onDirectoryChanged!(newDirectory);
    }
  }

  Widget _buildResizeHandle() {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) {
          setState(() {
            width = (width + details.delta.dx).clamp(
                widget.editorConfigService.config.uiFontSize * 11.0,
                MediaQuery.of(context).size.width - 200);
          });
        },
        child: Container(
          width: 1,
          height: double.infinity,
          color: widget.editorConfigService.themeService.currentTheme != null
              ? widget.editorConfigService.themeService.currentTheme!.border
              : Colors.transparent,
        ),
      ),
    );
  }

  Widget _buildFileTree(FileSystemEntity entity, int depth) {
    final fileName = entity.path.split(Platform.pathSeparator).last;
    final isDirectory = entity is Directory;
    final isExpanded = expandedDirs[entity.path] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CustomPaint(
          painter: IndentPainter(
              level: depth,
              lineColor: widget.editorConfigService.themeService.currentTheme !=
                      null
                  ? widget.editorConfigService.themeService.currentTheme!.text
                      .withOpacity(0.3)
                  : Colors.black.withOpacity(0.3)),
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
            fontSize: widget.editorConfigService.config.uiFontSize,
            onTap: () {
              if (isDirectory) {
                setState(() {
                  expandedDirs[entity.path] = !isExpanded;
                });
              } else {
                widget.tapCallback(entity.path);
              }
            },
            gitStatus: entity is File
                ? _fileStatuses[path.relative(entity.path,
                    from: widget.fileService.rootDirectory)]
                : _hasModifiedChildren(
                        path.relative(entity.path,
                            from: widget.fileService.rootDirectory),
                        _fileStatuses)
                    ? FileStatus.modified
                    : null,
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
    return ListenableBuilder(
        listenable: widget.editorConfigService,
        builder: (context, child) {
          width = width.clamp(
              max(widget.editorConfigService.config.uiFontSize * 11.0, 170.0),
              MediaQuery.of(context).size.width - 200);

          return Align(
            alignment: Alignment.topLeft,
            child: Row(
              children: [
                if (!widget.editorConfigService.config.isFileExplorerOnLeft)
                  _buildResizeHandle(),
                Container(
                  color: widget.editorConfigService.themeService.currentTheme !=
                          null
                      ? widget.editorConfigService.themeService.currentTheme!
                          .background
                      : Colors.white,
                  height: double.infinity,
                  width: width,
                  child: FutureBuilder<List<FileSystemEntity>>(
                    future: widget.fileService.filesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return Center(
                          child: TextButton(
                            onPressed: () async {
                              String? selectedDirectory =
                                  await FilePicker.platform.getDirectoryPath();

                              if (selectedDirectory != null) {
                                await _handleDirectoryChanged(
                                    selectedDirectory);
                              }
                            },
                            child: Text(
                              'Select a Directory',
                              style: TextStyle(
                                color: widget.editorConfigService.themeService
                                        .currentTheme?.text ??
                                    Colors.grey,
                              ),
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
                            editorConfigService: widget.editorConfigService,
                            onRefresh: () {
                              setState(() {
                                widget.fileService.filesFuture =
                                    widget.fileService.enumerateFiles(
                                        widget.fileService.rootDirectory);
                                _updateFileStatuses();
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
                            onNewFile: _createNewFile,
                            onNewFolder: _createNewFolder,
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
                                        .withOpacity(0.65)
                                    : Colors.grey[400]!.withOpacity(0.65)),
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
                if (widget.editorConfigService.config.isFileExplorerOnLeft)
                  _buildResizeHandle(),
              ],
            ),
          );
        });
  }
}
