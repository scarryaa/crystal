import 'dart:ui';

class FileCommands {
  final VoidCallback openConfig;
  final VoidCallback openDefaultConfig;
  final VoidCallback openNewTab;
  final Future<void> Function() saveFile;
  final Future<void> Function() saveFileAs;

  FileCommands({
    required this.openConfig,
    required this.openDefaultConfig,
    required this.openNewTab,
    required this.saveFile,
    required this.saveFileAs,
  });
}
