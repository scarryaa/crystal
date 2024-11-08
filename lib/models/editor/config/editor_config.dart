class EditorConfig {
  double fontSize;
  double uiFontSize;
  String fontFamily;
  double whitespaceIndicatorRadius;
  bool isFileExplorerVisible;
  String? currentDirectory;

  EditorConfig({
    required this.fontSize,
    required this.uiFontSize,
    required this.fontFamily,
    required this.whitespaceIndicatorRadius,
    this.isFileExplorerVisible = true,
    this.currentDirectory = '',
  });
}
