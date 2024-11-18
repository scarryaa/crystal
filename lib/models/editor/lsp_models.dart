class Diagnostic {
  final String message;
  final DiagnosticSeverity severity;
  final Range range;
  final String? code;
  final CodeDescription? codeDescription;
  final String? source;
  final List<DiagnosticRelatedInformation>? relatedInformation;
  final List<DiagnosticTag>? tags;
  final Map<String, dynamic>? data;

  Diagnostic({
    required this.message,
    required this.severity,
    required this.range,
    this.code,
    this.codeDescription,
    this.source,
    this.relatedInformation,
    this.tags,
    this.data,
  });

  factory Diagnostic.fromJson(Map<String, dynamic> json) {
    return Diagnostic(
      message: json['message'] as String,
      severity: DiagnosticSeverity.values[json['severity'] as int],
      range: Range.fromJson(json['range'] as Map<String, dynamic>),
      code: json['code'] as String?,
      codeDescription: json['codeDescription'] != null
          ? CodeDescription.fromJson(
              json['codeDescription'] as Map<String, dynamic>)
          : null,
      source: json['source'] as String?,
      relatedInformation: (json['relatedInformation'] as List<dynamic>?)
          ?.map((e) =>
              DiagnosticRelatedInformation.fromJson(e as Map<String, dynamic>))
          .toList(),
      tags: (json['tags'] as List<dynamic>?)
          ?.map((e) => DiagnosticTag.values[e as int])
          .toList(),
      data: json['data'] as Map<String, dynamic>?,
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
