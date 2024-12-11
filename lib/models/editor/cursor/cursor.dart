class Cursor {
  int line;
  int index;

  Cursor({required this.line, required this.index});

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cursor && other.line == line && other.index == index;
  }

  @override
  int get hashCode => Object.hash(line, index);

  @override
  String toString() => 'Cursor line: $line index $index';
}
