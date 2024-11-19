import 'package:crystal/models/languages/brace_based.dart';

class CSharp extends BraceBasedLanguage {
  @override
  String get name => 'C#';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'class',
        'interface',
        'namespace',
        'using',
        'public',
        'private',
        'protected',
        'internal',
        'static',
        'async',
        'await',
        'if',
        'else',
        'for',
        'foreach',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'new',
        'return'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'bool',
        'char',
        'string',
        'object',
        'dynamic',
        'var'
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
        '=>',
        '??'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp stringLiteral = RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '@"[^"]*"');
}
