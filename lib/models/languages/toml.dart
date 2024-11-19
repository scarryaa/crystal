import 'package:crystal/models/languages/language.dart';

class TOML extends Language {
  @override
  String get name => 'TOML';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => ['true', 'false'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['[', ']', '=', '.', ','];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '"""[\\s\\S]*?"""');
  @override
  RegExp get numberLiteral => RegExp(r'-?\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
