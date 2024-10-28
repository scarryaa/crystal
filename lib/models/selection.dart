class Selection {
  int startLine;
  int endLine;
  int startColumn;
  int endColumn;

  Selection(
      {required this.startLine,
      required this.endLine,
      required this.startColumn,
      required this.endColumn});

  bool get hasSelection =>
      (startLine == endLine && startColumn != endColumn) ||
      startLine != endLine;
}
