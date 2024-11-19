import 'package:crystal/models/languages/brace_based.dart';

class Rust extends BraceBasedLanguage {
  @override
  String get name => 'Rust';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'fn',
        'let',
        'mut',
        'pub',
        'struct',
        'enum',
        'trait',
        'impl',
        'use',
        'mod',
        'match',
        'if',
        'else',
        'for',
        'while',
        'loop',
        'return',
        'break',
        'continue',
        'unsafe'
      ];
  @override
  List<String> get types => [
        'i32',
        'i64',
        'u32',
        'u64',
        'f32',
        'f64',
        'bool',
        'char',
        'str',
        'String',
        'Vec',
        'Option',
        'Result'
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
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|r#"[^"]*"#)');
}
