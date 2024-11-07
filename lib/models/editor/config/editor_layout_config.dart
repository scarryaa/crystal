class EditorLayoutConfig {
  double horizontalPadding;
  int verticalPaddingLines;
  double verticalPadding;
  double lineHeightMultiplier;
  double lineHeight;
  double charWidth;

  EditorLayoutConfig({
    required double fontSize,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultiplier,
    required this.charWidth,
  })  : lineHeight = fontSize * lineHeightMultiplier,
        verticalPadding =
            verticalPaddingLines * (fontSize * lineHeightMultiplier);
}
