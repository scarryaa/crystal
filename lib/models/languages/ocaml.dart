import 'package:crystal/models/languages/language.dart';

class OCaml extends Language {
  @override
  String get name => 'OCaml';

  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'and',
        'as',
        'assert',
        'begin',
        'class',
        'constraint',
        'do',
        'done',
        'downto',
        'else',
        'end',
        'exception',
        'external',
        'false',
        'for',
        'fun',
        'function',
        'functor',
        'if',
        'in',
        'include',
        'inherit',
        'initializer',
        'lazy',
        'let',
        'match',
        'method',
        'module',
        'mutable',
        'new',
        'object',
        'of',
        'open',
        'private',
        'rec',
        'sig',
        'struct',
        'then',
        'to',
        'true',
        'try',
        'type',
        'val',
        'virtual',
        'when',
        'while',
        'with'
      ];

  @override
  List<String> get types => [
        'int',
        'float',
        'bool',
        'char',
        'string',
        'unit',
        'list',
        'array',
        'option',
        'ref'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '=',
        '<>',
        '<',
        '>',
        '<=',
        '>=',
        '@',
        '^',
        '|',
        '&',
        '::',
        ';',
        ':=',
        ';;',
        '->',
        '=>'
      ];

  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');

  @override
  RegExp get commentSingle => RegExp(r'\(\*.*\*\)');

  @override
  RegExp get commentMulti => RegExp(r'\(\*[\s\S]*?\*\)');
}
