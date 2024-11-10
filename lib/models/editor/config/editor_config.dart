class EditorConfig {
  double fontSize;
  double uiFontSize;
  String fontFamily;
  double whitespaceIndicatorRadius;
  bool isFileExplorerVisible;
  bool isFileExplorerOnLeft;
  double fileExplorerWidth;
  String theme;
  String? currentDirectory;

  EditorConfig({
    required this.fontSize,
    required this.uiFontSize,
    required this.fontFamily,
    required this.whitespaceIndicatorRadius,
    required this.fileExplorerWidth,
    required this.theme,
    this.isFileExplorerVisible = true,
    this.isFileExplorerOnLeft = true,
    this.currentDirectory = '',
  });
}
