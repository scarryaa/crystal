import 'package:crystal/models/languages/indentation_based.dart';

class Ruby extends IndentationBasedLanguage {
  @override
  String get name => 'Ruby';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'def',
        'class',
        'module',
        'if',
        'else',
        'elsif',
        'unless',
        'case',
        'when',
        'while',
        'until',
        'for',
        'begin',
        'rescue',
        'ensure',
        'end',
        'yield',
        'return'
      ];
  @override
  List<String> get types => [
        'Integer',
        'Float',
        'String',
        'Array',
        'Hash',
        'Symbol',
        'NilClass',
        'TrueClass',
        'FalseClass'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '=>',
        '<<'
      ];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '%[qQ]?{(?:[^{}\\\\]|\\\\.)*}');
}
