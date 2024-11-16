// file_explorer_container.dart
import 'package:crystal/providers/file_explorer_provider.dart';
import 'package:crystal/screens/editor/file_explorer/file_explorer_content.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FileExplorerContainer extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final Future<void> Function(String path, {int? row, int? col}) tapCallback;
  final GitService gitService;

  const FileExplorerContainer({
    super.key,
    required this.editorConfigService,
    required this.fileService,
    required this.tapCallback,
    required this.onDirectoryChanged,
    required this.gitService,
  });

  @override
  State<StatefulWidget> createState() => _FileExplorerContainerState();
}

class _FileExplorerContainerState extends State<FileExplorerContainer> {
  @override
  Widget build(BuildContext context) {
    return _buildFileExplorer();
  }

  Widget _buildFileExplorer() {
    return Consumer<FileExplorerProvider>(
      builder: (context, provider, child) {
        if (provider.isVisible) {
          return FileExplorerContent(
            editorConfigService: widget.editorConfigService,
            fileService: widget.fileService,
            tapCallback: widget.tapCallback,
            onDirectoryChanged: widget.onDirectoryChanged,
            gitService: widget.gitService,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
