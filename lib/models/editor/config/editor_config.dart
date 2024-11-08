class EditorConfig {
  double fontSize;
  String fontFamily;
  double whitespaceIndicatorRadius;
  bool isFileExplorerVisible;

  EditorConfig({
    required this.fontSize,
    required this.fontFamily,
    required this.whitespaceIndicatorRadius,
    this.isFileExplorerVisible = true,
  });
}
