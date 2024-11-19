import 'package:crystal/models/languages/language.dart';

class INI extends Language {
  @override
  String get name => 'INI';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['[', ']', '='];
  @override
  RegExp get commentSingle => RegExp(r';.*|#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}
