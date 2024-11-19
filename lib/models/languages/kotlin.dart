import 'package:crystal/models/languages/brace_based.dart';

class Kotlin extends BraceBasedLanguage {
  @override
  String get name => 'Kotlin';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'fun',
        'val',
        'var',
        'class',
        'interface',
        'object',
        'suspend',
        'when',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'return',
        'continue',
        'break',
        'as',
        'is',
        'in',
        'out',
        'super',
        'this'
      ];
  @override
  List<String> get types => [
        'Int',
        'Long',
        'Float',
        'Double',
        'Boolean',
        'Char',
        'String',
        'Array',
        'List',
        'Map'
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
        '?',
        '!!'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|"""[\s\S]*?""")');
}
