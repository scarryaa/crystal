import 'package:crystal/models/languages/language.dart';

class Vue extends Language {
  @override
  String get name => 'Vue';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'template',
        'script',
        'style',
        'export',
        'default',
        'props',
        'data',
        'computed',
        'methods',
        'watch',
        'components'
      ];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols =>
      ['<', '>', '/', '=', '@', ':', '.', '{', '}', '(', ')', '[', ']'];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}
