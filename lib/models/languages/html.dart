import 'package:crystal/models/languages/language.dart';

class HTML extends Language {
  @override
  String get name => 'HTML';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords =>
      ['DOCTYPE', 'html', 'head', 'body', 'script', 'style', 'link', 'meta'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['<', '>', '/', '='];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp(r'<!--[\s\S]*?-->');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
}
