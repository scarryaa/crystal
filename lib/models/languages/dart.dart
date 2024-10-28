import 'package:crystal/models/languages/language.dart';

class Dart extends Language {
  @override
  List<String> get keywords => [
        'abstract',
        'as',
        'assert',
        'async',
        'await',
        'break',
        'case',
        'catch',
        'class',
        'const',
        'continue',
        'default',
        'deferred',
        'do',
        'dynamic',
        'else',
        'enum',
        'export',
        'extends',
        'external',
        'factory',
        'false',
        'final',
        'finally',
        'for',
        'get',
        'if',
        'implements',
        'import',
        'in',
        'is',
        'library',
        'new',
        'null',
        'operator',
        'part',
        'rethrow',
        'return',
        'set',
        'static',
        'super',
        'switch',
        'sync',
        'this',
        'throw',
        'true',
        'try',
        'typedef',
        'var',
        'void',
        'while',
        'with',
        'yield'
      ];

  @override
  List<String> get types => [
        'bool',
        'double',
        'int',
        'num',
        'String',
        'List',
        'Map',
        'Set',
        'Future',
        'Stream',
        'Object',
        'dynamic',
        'void'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '=',
        '==',
        '!=',
        '>',
        '<',
        '>=',
        '<=',
        '++',
        '--',
        '+=',
        '-=',
        '*=',
        '/=',
        '??',
        '?.',
        '?',
        '!',
        '|',
        '&',
        '^',
        '~',
        '<<',
        '>>',
        '>>>',
        '|=',
        '&=',
        '^=',
        '~/'
      ];

  @override
  RegExp get stringLiteral =>
      RegExp(r'("(?:[^"\\]|\\.)*")|' r"('(?:[^'\\]|\\.)*')");

  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\.?\d*\b');

  @override
  RegExp get commentSingle => RegExp(r'//.*$', multiLine: true);

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/', multiLine: true);
}
