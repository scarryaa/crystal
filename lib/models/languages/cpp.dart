import 'package:crystal/models/languages/brace_based.dart';

class CPP extends BraceBasedLanguage {
  @override
  String get name => 'C++';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'class',
        'struct',
        'template',
        'typename',
        'namespace',
        'using',
        'public',
        'private',
        'protected',
        'virtual',
        'override',
        'const',
        'static',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'throw',
        'new',
        'delete'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'bool',
        'char',
        'void',
        'auto',
        'string',
        'vector'
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
        '::',
        '->',
        '<<',
        '>>'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');
}
