abstract class Language {
  List<String> get keywords;
  List<String> get types;
  List<String> get symbols;
  RegExp get stringLiteral;
  RegExp get numberLiteral;
  RegExp get commentSingle;
  RegExp get commentMulti;
}
