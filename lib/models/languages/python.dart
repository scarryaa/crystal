import 'package:crystal/models/languages/indentation_based.dart';

class Python extends IndentationBasedLanguage {
  @override
  String get name => 'Python';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'def',
        'class',
        'if',
        'else',
        'elif',
        'for',
        'while',
        'try',
        'except',
        'finally',
        'with',
        'as',
        'import',
        'from',
        'return',
        'yield',
        'break',
        'continue',
        'pass',
        'raise',
        'True',
        'False',
        'None',
        'and',
        'or',
        'not',
        'is',
        'in',
        'lambda',
        'nonlocal',
        'global',
        'assert',
        'async',
        'await'
      ];

  @override
  List<String> get types => [
        'int',
        'float',
        'str',
        'bool',
        'list',
        'dict',
        'tuple',
        'set',
        'bytes',
        'object'
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
        ';'
      ];

  @override
  RegExp get commentSingle => RegExp(r'#.*');

  @override
  RegExp get commentMulti =>
      RegExp('(?:"""[\\s\\S]*?"""|\'\'\'[\\s\\S]*?\'\'\')');

  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
