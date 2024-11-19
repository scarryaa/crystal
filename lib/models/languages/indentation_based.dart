import 'package:crystal/models/languages/language.dart';

abstract class IndentationBasedLanguage extends Language {
  bool get usesIndentationFolding => true;

  @override
  RegExp get commentMulti => RegExp('');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}
