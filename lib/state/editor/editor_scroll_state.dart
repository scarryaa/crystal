class EditorScrollState {
  double verticalOffset = 0.0;
  double horizontalOffset = 0.0;
  double minScrollExtent = 0.0;
  double maxScrollExtent = 0.0;

  bool get atEdge =>
      verticalOffset <= minScrollExtent || verticalOffset >= maxScrollExtent;
}
