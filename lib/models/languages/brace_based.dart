import 'package:crystal/models/languages/language.dart';

abstract class BraceBasedLanguage extends Language {
  bool get usesIndentationFolding => false;

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
