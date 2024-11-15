import 'package:crystal/models/languages/dart.dart';
import 'package:crystal/models/languages/language.dart';

class LanguageDetectionService {
  static final Map<String, Language> _extensionToLanguage = {
    'dart': Dart(),
  };

  static Language getLanguageFromFilename(String filename) {
    final extension = _getFileExtension(filename);
    return _extensionToLanguage[extension.toLowerCase()] ?? UnknownLanguage();
  }

  static String _getFileExtension(String filename) {
    final parts = filename.split('.');
    return parts.isNotEmpty ? parts.last : '';
  }
}

// Fallback language for unknown file types
class UnknownLanguage extends Language {
  @override
  String get name => 'Unknown';
  @override
  List<String> get keywords => [];

  @override
  List<String> get types => [];

  @override
  List<String> get symbols => [];

  @override
  RegExp get stringLiteral => RegExp(r'".*?"');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');

  @override
  RegExp get commentSingle => RegExp(r'//.*');

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
}
