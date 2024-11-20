import 'dart:ui';

class FileConfig {
  final String fileName;
  final bool isDirty;
  final Function(int index) onEditorClosed;
  final Future<void> Function() saveFileAs;
  final Future<void> Function() saveFile;
  final VoidCallback openNewTab;
  final Function activeEditorIndex;

  FileConfig({
    required this.fileName,
    required this.isDirty,
    required this.onEditorClosed,
    required this.saveFileAs,
    required this.saveFile,
    required this.openNewTab,
    required this.activeEditorIndex,
  });
}
