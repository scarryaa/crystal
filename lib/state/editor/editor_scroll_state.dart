class EditorScrollState {
  double verticalOffset = 0.0;
  double horizontalOffset = 0.0;
  double minScrollExtent = 0.0;
  double maxScrollExtent = 0.0;
  double viewportHeight = 0.0;
  double viewportWidth = 0.0;

  bool get atEdge =>
      verticalOffset <= minScrollExtent || verticalOffset >= maxScrollExtent;

  void updateVerticalScrollOffset(double offset) {
    verticalOffset = offset;
  }

  void updateHorizontalScrollOffset(double offset) {
    horizontalOffset = offset;
  }

  void updateViewportHeight(double height) {
    viewportHeight = height;
  }

  void updateViewportWidth(double width) {
    viewportWidth = width;
  }
}
