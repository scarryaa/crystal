import 'package:crystal/models/languages/language.dart';

class JSON extends Language {
  @override
  String get name => 'JSON';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => ['true', 'false', 'null'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['{', '}', '[', ']', ':', ','];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
  @override
  RegExp get numberLiteral => RegExp(r'-?\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
