import 'package:crystal/models/languages/brace_based.dart';

class Lua extends BraceBasedLanguage {
  @override
  String get name => 'Lua';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'and',
        'break',
        'do',
        'else',
        'elseif',
        'end',
        'false',
        'for',
        'function',
        'if',
        'in',
        'local',
        'nil',
        'not',
        'or',
        'repeat',
        'return',
        'then',
        'true',
        'until',
        'while'
      ];
  @override
  List<String> get types => [
        'nil',
        'number',
        'string',
        'boolean',
        'table',
        'function',
        'userdata',
        'thread'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '^',
        '#',
        '==',
        '~=',
        '<=',
        '>=',
        '<',
        '>',
        '=',
        '(',
        ')',
        '{',
        '}',
        '[',
        ']',
        ';',
        ':',
        ',',
        '.',
        '..'
      ];
  @override
  RegExp get commentSingle => RegExp(r'--.*');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
}
