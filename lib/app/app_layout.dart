import 'package:crystal/app/title_bar.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final Function()? onDirectoryRefresh;
  final FileService fileService;

  const AppLayout({
    super.key,
    required this.child,
    required this.editorConfigService,
    required this.fileService,
    required this.onDirectoryChanged,
    required this.onDirectoryRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TitleBar(
            editorConfigService: editorConfigService,
            onDirectoryChanged: onDirectoryChanged,
            onDirectoryRefresh: onDirectoryRefresh,
            fileService: fileService,
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
