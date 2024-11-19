import 'package:crystal/models/languages/brace_based.dart';

class Go extends BraceBasedLanguage {
  @override
  String get name => 'Go';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'func',
        'interface',
        'struct',
        'type',
        'package',
        'import',
        'if',
        'else',
        'for',
        'range',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'go',
        'chan',
        'defer',
        'select'
      ];
  @override
  List<String> get types => [
        'int',
        'int64',
        'float64',
        'bool',
        'string',
        'error',
        'interface{}',
        'byte',
        'rune'
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
        ':=',
        '...'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|`[^`]*`)');
}
