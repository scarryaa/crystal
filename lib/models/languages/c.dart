import 'package:crystal/models/languages/brace_based.dart';

class C extends BraceBasedLanguage {
  @override
  String get name => 'C';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'goto',
        'typedef',
        'struct',
        'enum',
        'union',
        'sizeof'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'char',
        'void',
        'unsigned',
        'signed',
        'short',
        'const'
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
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
}
