import 'package:crystal/models/languages/language.dart';

class Shell extends Language {
  @override
  String get name => 'Shell';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'if',
        'then',
        'else',
        'elif',
        'fi',
        'case',
        'esac',
        'for',
        'while',
        'do',
        'done',
        'function'
      ];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['|', '>', '<', '&', ';', '[', ']', '{', '}'];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
}
