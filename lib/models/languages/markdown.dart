import 'package:crystal/models/languages/indentation_based.dart';

class Markdown extends IndentationBasedLanguage {
  @override
  String get name => 'Markdown';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => []; // Markdown doesn't have traditional keywords

  @override
  List<String> get types => []; // Markdown doesn't have types

  @override
  List<String> get symbols =>
      ['#', '*', '_', '`', '~', '>', '-', '+', '=', '[', ']', '(', ')', '|'];

  @override
  RegExp get commentSingle => RegExp(r'<!--.*-->');

  @override
  RegExp get commentMulti => RegExp(r'<!--[\s\S]*?-->');

  @override
  RegExp get stringLiteral => RegExp(r'`[^`]*`');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
