import 'package:crystal/models/languages/brace_based.dart';

class Java extends BraceBasedLanguage {
  @override
  String get name => 'Java';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'abstract',
        'class',
        'extends',
        'implements',
        'interface',
        'public',
        'private',
        'protected',
        'static',
        'final',
        'void',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'throws',
        'new',
        'return',
        'break',
        'continue',
        'instanceof'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'boolean',
        'char',
        'byte',
        'short',
        'String',
        'Object'
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
        '?',
        '!'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
}
