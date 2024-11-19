import 'package:crystal/models/languages/indentation_based.dart';

class YAML extends IndentationBasedLanguage {
  @override
  String get name => 'YAML';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords =>
      ['true', 'false', 'null', 'yes', 'no', 'on', 'off'];

  @override
  List<String> get types => []; // YAML doesn't have explicit types

  @override
  List<String> get symbols =>
      [':', '-', '>', '|', '&', '*', '!', '?', '%', '@', '`'];

  @override
  RegExp get commentSingle => RegExp(r'#.*');

  @override
  RegExp get commentMulti =>
      RegExp(r''); // YAML doesn't have multi-line comments

  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
