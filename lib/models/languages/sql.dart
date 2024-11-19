import 'package:crystal/models/languages/language.dart';

class SQL extends Language {
  @override
  String get name => 'SQL';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'SELECT',
        'FROM',
        'WHERE',
        'INSERT',
        'UPDATE',
        'DELETE',
        'CREATE',
        'ALTER',
        'DROP',
        'TABLE',
        'INDEX',
        'JOIN',
        'GROUP',
        'BY',
        'HAVING',
        'ORDER',
        'LIMIT'
      ];
  @override
  List<String> get types => [
        'INTEGER',
        'VARCHAR',
        'TEXT',
        'DATE',
        'TIMESTAMP',
        'BOOLEAN',
        'FLOAT',
        'DOUBLE',
        'DECIMAL'
      ];
  @override
  List<String> get symbols => [
        '=',
        '<',
        '>',
        '<=',
        '>=',
        '!=',
        '(',
        ')',
        ',',
        '.',
        ';',
        '*',
        '+',
        '-',
        '/'
      ];
  @override
  RegExp get commentSingle => RegExp(r'--.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}
