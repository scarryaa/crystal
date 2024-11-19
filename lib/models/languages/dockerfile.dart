import 'package:crystal/models/languages/language.dart';

class Dockerfile extends Language {
  @override
  String get name => 'Dockerfile';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'FROM',
        'RUN',
        'CMD',
        'LABEL',
        'MAINTAINER',
        'EXPOSE',
        'ENV',
        'ADD',
        'COPY',
        'ENTRYPOINT',
        'VOLUME',
        'USER',
        'WORKDIR',
        'ARG',
        'ONBUILD',
        'STOPSIGNAL',
        'HEALTHCHECK',
        'SHELL'
      ];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['=', '\\'];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
}
