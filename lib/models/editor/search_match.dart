class SearchMatch {
  final int lineNumber;
  final int startIndex;
  final int length;

  SearchMatch({
    required this.lineNumber,
    required this.startIndex,
    this.length = 1,
  });

  @override
  String toString() =>
      'SearchMatch(line: $lineNumber, start: $startIndex, length: $length)';
}
