class EditorLayoutConfig {
  double horizontalPadding;
  int verticalPaddingLines;
  double verticalPadding;
  double lineHeightMultiplier;
  double lineHeight;

  EditorLayoutConfig({
    required double fontSize,
    required this.horizontalPadding,
    required this.verticalPaddingLines,
    required this.lineHeightMultiplier,
  })  : lineHeight = fontSize * lineHeightMultiplier,
        verticalPadding =
            verticalPaddingLines * (fontSize * lineHeightMultiplier);
}
