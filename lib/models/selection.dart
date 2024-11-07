class Selection {
  int startLine;
  int endLine;
  int startColumn;
  int endColumn;
  int anchorLine;
  int anchorColumn;

  Selection({
    required this.startLine,
    required this.endLine,
    required this.startColumn,
    required this.endColumn,
    required this.anchorLine,
    required this.anchorColumn,
  });

  bool get hasSelection =>
      (startLine == endLine && startColumn != endColumn) ||
      startLine != endLine;

  @override
  String toString() {
    return 'Selection(startLine: $startLine, endLine: $endLine, startColumn: $startColumn, endColumn: $endColumn, anchorLine: $anchorLine, anchorColumn: $anchorColumn)';
  }
}
