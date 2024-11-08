class EditorConfig {
  double fontSize;
  double uiFontSize;
  String fontFamily;
  double whitespaceIndicatorRadius;
  bool isFileExplorerVisible;
  double fileExplorerWidth;
  String? currentDirectory;

  EditorConfig({
    required this.fontSize,
    required this.uiFontSize,
    required this.fontFamily,
    required this.whitespaceIndicatorRadius,
    required this.fileExplorerWidth,
    this.isFileExplorerVisible = true,
    this.currentDirectory = '',
  });
}
