class Cursor {
  int line;
  int column;

  Cursor(this.line, this.column);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Cursor && other.line == line && other.column == column;
  }

  @override
  int get hashCode => Object.hash(line, column);
}
