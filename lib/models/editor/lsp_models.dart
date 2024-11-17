class Diagnostic {
  final String message;
  final DiagnosticSeverity severity;
  final Range range;

  Diagnostic({
    required this.message,
    required this.severity,
    required this.range,
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    return Diagnostic(
      message: json['message'] as String,
      severity: DiagnosticSeverity.values[json['severity'] as int],
      range: Range.fromJson(json['range'] as Map<String, dynamic>),
    );
  }
}

class Range {
  final Position start;
  final Position end;

  Range({required this.start, required this.end});

  factory Range.fromJson(Map<String, dynamic> json) {
    return Range(
      start: Position.fromJson(json['start'] as Map<String, dynamic>),
      end: Position.fromJson(json['end'] as Map<String, dynamic>),
    );
  }
}

class Position {
  final int line;
  final int character;

  Position({required this.line, required this.character});

  factory Position.fromJson(Map<String, dynamic> json) {
    return Position(
      line: json['line'] as int,
      character: json['character'] as int,
    );
  }
}

enum DiagnosticSeverity {
  error,
  warning,
  information,
  hint,
}
