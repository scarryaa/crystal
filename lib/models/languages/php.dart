import 'package:crystal/models/languages/brace_based.dart';

class PHP extends BraceBasedLanguage {
  @override
  String get name => 'PHP';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'function',
        'class',
        'interface',
        'trait',
        'extends',
        'implements',
        'public',
        'private',
        'protected',
        'if',
        'else',
        'elseif',
        'foreach',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw'
      ];
  @override
  List<String> get types => [
        'int',
        'float',
        'string',
        'bool',
        'array',
        'object',
        'null',
        'resource',
        'callable'
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
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'(?://.*|#.*)');
  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');
}
