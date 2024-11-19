import 'package:crystal/models/languages/language.dart';

class R extends Language {
  @override
  String get name => 'R';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'if',
        'else',
        'repeat',
        'while',
        'function',
        'for',
        'in',
        'next',
        'break',
        'TRUE',
        'FALSE',
        'NULL',
        'Inf',
        'NaN'
      ];
  @override
  List<String> get types => [
        'numeric',
        'integer',
        'complex',
        'logical',
        'character',
        'factor',
        'list',
        'matrix'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '^',
        '=',
        '<-',
        '->',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        '\$',
        '@',
        ':',
        ','
      ];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
