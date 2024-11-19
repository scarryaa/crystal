import 'package:crystal/models/languages/brace_based.dart';

class JavaScript extends BraceBasedLanguage {
  @override
  String get name => 'JavaScript';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'function',
        'class',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'throw',
        'const',
        'let',
        'var',
        'new',
        'this',
        'super',
        'extends',
        'null',
        'undefined',
        'true',
        'false',
        'async',
        'await',
        'yield',
        'typeof',
        'instanceof',
        'in'
      ];

  @override
  List<String> get types => [
        'number',
        'string',
        'boolean',
        'object',
        'symbol',
        'bigint',
        'undefined',
        'null'
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
        '===',
        '!=',
        '!==',
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
        '...'
      ];

  @override
  RegExp get commentSingle => RegExp(r'//.*');

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');

  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '`(?:[^`\\\\]|\\\\.)*`');

  @override
  RegExp get numberLiteral =>
      RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b|0[xX][0-9a-fA-F]+\b');
}
