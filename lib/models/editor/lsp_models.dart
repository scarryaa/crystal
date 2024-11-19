class Diagnostic {
  final String message;
  final DiagnosticSeverity severity;
  final Range range;
  final String? code;
  final String source;
  final CodeDescription? codeDescription;
  final List<DiagnosticRelatedInformation>? relatedInformation;

  final List<DiagnosticTag>? tags;

  Diagnostic({
    required this.message,
    required this.severity,
    required this.range,
    this.code,
    this.relatedInformation,
    this.codeDescription,
    required this.source,
    this.tags,
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    return Diagnostic(
      message: json['message'] as String,
      severity: DiagnosticSeverity.values[(json['severity'] as int) - 1],
      range: Range.fromJson(json['range'] as Map<String, dynamic>),
      code: json['code']?.toString(),
      source: json['source'] as String,
      tags: json['tags'] == null
          ? null
          : List<DiagnosticTag>.from(
              (json['tags'] as List).map((x) => DiagnosticTag.values[x - 1])),
    );
  }
}

class CodeDescription {
  final String href;

  CodeDescription({required this.href});

  factory CodeDescription.fromJson(Map<String, dynamic> json) {
    return CodeDescription(href: json['href'] as String);
  }
}

class DiagnosticRelatedInformation {
  final Location location;
  final String message;

  DiagnosticRelatedInformation({required this.location, required this.message});

  factory DiagnosticRelatedInformation.fromJson(Map<String, dynamic> json) {
    return DiagnosticRelatedInformation(
      location: Location.fromJson(json['location'] as Map<String, dynamic>),
      message: json['message'] as String,
    );
  }
}

class Location {
  final String uri;
  final Range range;

  Location({required this.uri, required this.range});

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      uri: json['uri'] as String,
      range: Range.fromJson(json['range'] as Map<String, dynamic>),
    );
  }
}

enum DiagnosticTag {
  unnecessary,
  deprecated,
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
