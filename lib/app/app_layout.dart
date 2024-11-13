import 'dart:io';

import 'package:crystal/app/title_bar.dart';
import 'package:crystal/screens/editor_screen.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/file_service.dart';
import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final GlobalKey<EditorScreenState> editorKey;

  const AppLayout({
    super.key,
    required this.child,
    required this.editorConfigService,
    required this.fileService,
    required this.onDirectoryChanged,
    required this.editorKey,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          if (Platform.isMacOS)
            TitleBar(
              editorConfigService: editorConfigService,
              onDirectoryChanged: onDirectoryChanged,
              fileService: fileService,
              editorKey: editorKey,
            ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
