import 'package:crystal/models/languages/brace_based.dart';
import 'package:crystal/models/languages/javascript.dart';
import 'package:crystal/models/languages/language.dart';

class TypeScript extends BraceBasedLanguage {
  @override
  String get name => 'TypeScript';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords =>
      ['interface', 'type', 'enum', ...JavaScript().keywords];
  @override
  List<String> get types =>
      ['any', 'void', 'number', 'string', 'boolean', 'never', 'unknown'];
  @override
  List<String> get symbols => JavaScript().symbols;
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  final stringLiteral =
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|`(?:[^`\\\\]|\\\\.)*`');
}

class CSS extends Language {
  @override
  String get name => 'CSS';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => ['import', 'media', 'from', 'to', 'important'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['{', '}', ':', ';', ',', '.', '#', '@'];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral =>
      RegExp(r'\b\d*\.?\d+(%|px|em|rem|vh|vw|pt|pc)?\b');
}
