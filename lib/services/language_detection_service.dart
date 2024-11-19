import 'package:crystal/models/languages/c.dart';
import 'package:crystal/models/languages/cpp.dart';
import 'package:crystal/models/languages/csharp.dart';
import 'package:crystal/models/languages/dart.dart';
import 'package:crystal/models/languages/dockerfile.dart';
import 'package:crystal/models/languages/erlang.dart';
import 'package:crystal/models/languages/go.dart';
import 'package:crystal/models/languages/haskell.dart';
import 'package:crystal/models/languages/html.dart';
import 'package:crystal/models/languages/ini.dart';
import 'package:crystal/models/languages/java.dart';
import 'package:crystal/models/languages/javascript.dart';
import 'package:crystal/models/languages/json.dart';
import 'package:crystal/models/languages/kotlin.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:crystal/models/languages/lua.dart';
import 'package:crystal/models/languages/makefile.dart';
import 'package:crystal/models/languages/markdown.dart';
import 'package:crystal/models/languages/ocaml.dart';
import 'package:crystal/models/languages/php.dart';
import 'package:crystal/models/languages/python.dart';
import 'package:crystal/models/languages/r.dart';
import 'package:crystal/models/languages/ruby.dart';
import 'package:crystal/models/languages/rust.dart';
import 'package:crystal/models/languages/scss.dart';
import 'package:crystal/models/languages/shell.dart';
import 'package:crystal/models/languages/sql.dart';
import 'package:crystal/models/languages/svelte.dart';
import 'package:crystal/models/languages/swift.dart';
import 'package:crystal/models/languages/toml.dart';
import 'package:crystal/models/languages/typescript.dart';
import 'package:crystal/models/languages/unknown.dart';
import 'package:crystal/models/languages/vue.dart';
import 'package:crystal/models/languages/xml.dart';
import 'package:crystal/models/languages/yaml.dart';

class LanguageDetectionService {
  static final Map<String, Language> _extensionToLanguage = {
    // Common programming languages
    'dart': Dart(),
    'py': Python(),
    'js': JavaScript(),
    'ts': TypeScript(),
    'jsx': JavaScript(),
    'tsx': TypeScript(),
    'html': HTML(),
    'css': CSS(),
    'scss': SCSS(),
    'java': Java(),
    'kt': Kotlin(),
    'cpp': CPP(),
    'c': C(),
    'h': C(),
    'hpp': CPP(),
    'cs': CSharp(),
    'go': Go(),
    'rs': Rust(),
    'swift': Swift(),
    'rb': Ruby(),
    'php': PHP(),

    // Markup and config languages
    'xml': XML(),
    'json': JSON(),
    'yaml': YAML(),
    'yml': YAML(),
    'md': Markdown(),
    'markdown': Markdown(),
    'toml': TOML(),
    'ini': INI(),

    // Shell scripts
    'sh': Shell(),
    'bash': Shell(),
    'zsh': Shell(),

    // Other common formats
    'sql': SQL(),
    'r': R(),
    'dockerfile': Dockerfile(),
    'lua': Lua(),
    'vue': Vue(),
    'svelte': Svelte(),

    // C/C++ variations
    'cc': CPP(),
    'cxx': CPP(),
    'cp': CPP(),
    'hxx': CPP(),
    'h++': CPP(),
    'ixx': CPP(), // For C++ modules

    // Python variations
    'pyw': Python(),
    'pyi': Python(), // Type hint files

    // Web framework specific
    // ignore: equal_keys_in_map
    'jsx': JavaScript(),
    // ignore: equal_keys_in_map
    'tsx': TypeScript(),
    'mjs': JavaScript(), // ES modules
    'cjs': JavaScript(), // CommonJS modules

    // Ruby variations
    'rake': Ruby(),
    'gemspec': Ruby(),

    // Shell variations
    'fish': Shell(),
    'ksh': Shell(),

    'ml': OCaml(),
    'mli': OCaml(),
    'hs': Haskell(),
    'lhs': Haskell(),
    'erl': Erlang(),
    'hrl': Erlang(),

    // // Lisp family
    // 'lisp': Lisp(),
    // 'cl': Lisp(),
    // 'el': EmacsLisp(),

    // // Erlang ecosystem
    // 'erl': Erlang(),
    // 'hrl': Erlang(),
    // 'ex': Elixir(),
    // 'exs': Elixir(),

    // // F#
    // 'fs': FSharp(),
    // 'fsx': FSharp(),
    // 'fsi': FSharp(),

    // // Additional web formats
    // 'scss': SCSS(),
    // 'sass': SASS(),
    // 'less': Less(),
    // 'styl': Stylus(),

    // // Build systems
    // 'gradle': Gradle(),
    // 'bazel': Bazel(),
    // 'bzl': Bazel(),

    // // Config formats
    // 'conf': Config(),
    // 'config': Config(),
    // 'properties': Properties(),
  };

  static List<Language> getAvailableLanguages() {
    return [
      Dart(),
      Python(),
      JavaScript(),
      TypeScript(),
      HTML(),
      CSS(),
      SCSS(),
      Java(),
      Kotlin(),
      CPP(),
      C(),
      CPP(),
      CSharp(),
      Go(),
      Rust(),
      Swift(),
      Ruby(),
      PHP(),
      XML(),
      JSON(),
      YAML(),
      Markdown(),
      TOML(),
      INI(),
      SQL(),
      R(),
      Dockerfile(),
      Lua(),
      Vue(),
      Svelte(),
      CPP(),
      Python(),
      TypeScript(),
      JavaScript(),
      Ruby(),
      Shell(),
      OCaml(),
      Haskell(),
      Erlang(),
    ];
  }

  static Language getLanguageFromName(String name) {
    final nameToLanguage = {
      'dart': Dart(),
      'python': Python(),
      'javascript': JavaScript(),
      'typescript': TypeScript(),
      'html': HTML(),
      'css': CSS(),
      'scss': SCSS(),
      'java': Java(),
      'kotlin': Kotlin(),
      'c++': CPP(),
      'cpp': CPP(),
      'c': C(),
      'c#': CSharp(),
      'csharp': CSharp(),
      'go': Go(),
      'rust': Rust(),
      'swift': Swift(),
      'ruby': Ruby(),
      'php': PHP(),
      'xml': XML(),
      'json': JSON(),
      'yaml': YAML(),
      'markdown': Markdown(),
      'md': Markdown(),
      'toml': TOML(),
      'ini': INI(),
      'shell': Shell(),
      'bash': Shell(),
      'zsh': Shell(),
      'sql': SQL(),
      'r': R(),
      'dockerfile': Dockerfile(),
      'lua': Lua(),
      'vue': Vue(),
      'svelte': Svelte(),
      'ocaml': OCaml(),
      'haskell': Haskell(),
      'erlang': Erlang(),
    };

    return nameToLanguage[name.toLowerCase()] ?? UnknownLanguage();
  }

  /// Gets the language for a given filename.
  /// The extension matching is case-insensitive.
  static Language getLanguageFromFilename(String filename) {
    final extension = _getFileExtension(filename);
    // Special case for files without extension but with specific names
    if (extension.isEmpty || extension == filename.toLowerCase()) {
      final lowercaseFilename = filename.toLowerCase();
      if (lowercaseFilename == 'dockerfile') {
        return Dockerfile();
      }
      if (lowercaseFilename == 'makefile') {
        return Makefile();
      }
    }
    return _extensionToLanguage[extension.toLowerCase()] ?? UnknownLanguage();
  }

  /// Gets the file extension from a filename.
  /// Returns lowercase extension without the dot.
  static String _getFileExtension(String filename) {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }
}
