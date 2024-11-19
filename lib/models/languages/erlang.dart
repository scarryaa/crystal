import 'package:crystal/models/languages/language.dart';

class Erlang extends Language {
  @override
  String get name => 'Erlang';

  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'after',
        'begin',
        'case',
        'catch',
        'cond',
        'end',
        'fun',
        'if',
        'let',
        'of',
        'receive',
        'try',
        'when',
        'andalso',
        'orelse',
        'query',
        'spec',
        'div',
        'rem'
      ];

  @override
  List<String> get types => [
        'atom',
        'binary',
        'boolean',
        'float',
        'function',
        'integer',
        'list',
        'map',
        'pid',
        'port',
        'reference',
        'tuple'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '=',
        '==',
        '/=',
        '=<',
        '>=',
        '<',
        '>',
        '++',
        '--',
        '!',
        '?',
        ':',
        '->',
        '<-',
        '=>'
      ];

  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');

  @override
  RegExp get commentSingle => RegExp(r'%.*');

  @override
  RegExp get commentMulti => RegExp('');
}
