import 'package:crystal/models/languages/language.dart';

class Haskell extends Language {
  @override
  String get name => 'Haskell';

  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'case',
        'class',
        'data',
        'default',
        'deriving',
        'do',
        'else',
        'foreign',
        'if',
        'import',
        'in',
        'infix',
        'infixl',
        'infixr',
        'instance',
        'let',
        'module',
        'newtype',
        'of',
        'then',
        'type',
        'where',
        'qualified',
        'hiding'
      ];

  @override
  List<String> get types => [
        'Int',
        'Integer',
        'Float',
        'Double',
        'Bool',
        'Char',
        'String',
        'Maybe',
        'Either',
        'IO',
        'List',
        'Map'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '=',
        '/=',
        '<',
        '>',
        '<=',
        '>=',
        '++',
        '.',
        '\$',
        '<\$>',
        '<*>',
        '>>=',
        '->',
        '=>',
        '::',
        '|'
      ];

  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');

  @override
  RegExp get commentSingle => RegExp(r'--.*');

  @override
  RegExp get commentMulti => RegExp(r'\{-[\s\S]*?-\}');
}
