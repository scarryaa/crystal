import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/title_bar.dart';
import 'package:flutter/material.dart';

class AppLayout extends StatelessWidget {
  final Widget child;
  final EditorConfigService editorConfigService;
  final Function(String)? onDirectoryChanged;
  final Function()? onDirectoryRefresh;

  const AppLayout({
    super.key,
    required this.child,
    required this.editorConfigService,
    this.onDirectoryChanged,
    this.onDirectoryRefresh,
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
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}
