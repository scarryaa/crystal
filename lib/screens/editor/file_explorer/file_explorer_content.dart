import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/widgets/file_explorer/file_explorer.dart';
import 'package:flutter/material.dart';

class FileExplorerContent extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final Future<void> Function(String path, {int? row, int? col}) tapCallback;
  final GitService gitService;

  const FileExplorerContent({
    super.key,
    required this.editorConfigService,
    required this.fileService,
    required this.tapCallback,
    required this.onDirectoryChanged,
    required this.gitService,
  });

  @override
  State<FileExplorerContent> createState() => _FileExplorerContentState();
}

class _FileExplorerContentState extends State<FileExplorerContent> {
  @override
  Widget build(BuildContext context) {
    return FileExplorer(
      fileService: widget.fileService,
      tapCallback: widget.tapCallback,
      editorConfigService: widget.editorConfigService,
      onDirectoryChanged: widget.onDirectoryChanged,
      gitService: widget.gitService,
    );
  }
}
