import 'package:crystal/models/languages/typescript.dart';

class SCSS extends CSS {
  @override
  String get name => 'SCSS';
  @override
  List<String> get keywords => [
        ...super.keywords,
        'mixin',
        'include',
        'extend',
        'if',
        'else',
        'for',
        'each',
        'while'
      ];
  @override
  List<String> get symbols => [...super.symbols, '\$', '&', '%'];
}
