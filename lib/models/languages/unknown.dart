import 'package:crystal/models/languages/language.dart';

class UnknownLanguage extends Language {
  @override
  String get name => 'Unknown';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => [];
  bool get usesIndentationFolding => false;
  @override
  RegExp get stringLiteral => RegExp(r'".*?"');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
}
