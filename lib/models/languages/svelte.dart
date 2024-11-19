import 'package:crystal/models/languages/language.dart';

class Svelte extends Language {
  @override
  String get name => 'Svelte';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'script',
        'style',
        'if',
        'else',
        'each',
        'await',
        'then',
        'catch',
        'as',
        'export',
        'let',
        'const'
      ];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols =>
      ['<', '>', '/', '=', '{', '}', '(', ')', '[', ']', '#', ':', '@', '|'];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}
