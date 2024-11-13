class EditorConfig {
  double fontSize;
  double uiFontSize;
  String fontFamily;
  String uiFontFamily;
  double whitespaceIndicatorRadius;
  bool isFileExplorerVisible;
  bool isFileExplorerOnLeft;
  bool isTerminalVisible;
  double fileExplorerWidth;
  String theme;
  String? currentDirectory;
  double tabWidth;
  double terminalHeight;

  EditorConfig({
    required this.fontSize,
    required this.uiFontSize,
    required this.fontFamily,
    required this.uiFontFamily,
    required this.whitespaceIndicatorRadius,
    required this.fileExplorerWidth,
    required this.theme,
    required this.tabWidth,
    this.terminalHeight = 300.0,
    this.isFileExplorerVisible = true,
    this.isFileExplorerOnLeft = true,
    this.isTerminalVisible = false,
    this.currentDirectory = '',
  });
}
