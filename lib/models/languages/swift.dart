import 'package:crystal/models/languages/brace_based.dart';

class Swift extends BraceBasedLanguage {
  @override
  String get name => 'Swift';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'func',
        'var',
        'let',
        'class',
        'struct',
        'enum',
        'protocol',
        'extension',
        'if',
        'else',
        'guard',
        'switch',
        'case',
        'for',
        'while',
        'return',
        'throw',
        'try',
        'catch'
      ];
  @override
  List<String> get types => [
        'Int',
        'Double',
        'Float',
        'Bool',
        'String',
        'Character',
        'Array',
        'Dictionary',
        'Set',
        'Any'
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
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|"""[\s\S]*?""")');
}
