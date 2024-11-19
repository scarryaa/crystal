import 'package:crystal/models/languages/indentation_based.dart';

class Makefile extends IndentationBasedLanguage {
  @override
  String get name => 'Makefile';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'ifeq',
        'ifneq',
        'ifdef',
        'ifndef',
        'else',
        'endif',
        'include',
        'define',
        'endef',
        '.PHONY',
        '.DEFAULT',
        '.PRECIOUS',
        'export',
        'unexport',
        'vpath'
      ];

  @override
  List<String> get types => [];

  @override
  List<String> get symbols => [
        ':',
        '=',
        ':=',
        '?=',
        '+=',
        '\$',
        '(',
        ')',
        '{',
        '}',
        '@',
        '<',
        '>',
        '|',
        '*',
        '%',
        '\\',
        '&&'
      ];

  @override
  RegExp get commentSingle => RegExp(r'#.*');

  @override
  RegExp get commentMulti => RegExp('');

  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');

  @override
  bool get usesIndentationFolding => true;
}
