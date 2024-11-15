import 'package:crystal/models/languages/dart.dart';
import 'package:crystal/models/languages/language.dart';

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
    'jsx': JavaScript(),
    'tsx': TypeScript(),
    'mjs': JavaScript(), // ES modules
    'cjs': JavaScript(), // CommonJS modules

    // Ruby variations
    'rake': Ruby(),
    'gemspec': Ruby(),

    // Shell variations
    'fish': Shell(),
    'ksh': Shell(),

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

// Base classes for different language types
abstract class IndentationBasedLanguage extends Language {
  @override
  bool get usesIndentationFolding => true;

  @override
  RegExp get commentMulti => RegExp('');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

abstract class BraceBasedLanguage extends Language {
  @override
  bool get usesIndentationFolding => false;

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

// Language implementations
class TypeScript extends BraceBasedLanguage {
  @override
  String get name => 'TypeScript';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords =>
      ['interface', 'type', 'enum', ...JavaScript().keywords];
  @override
  List<String> get types =>
      ['any', 'void', 'number', 'string', 'boolean', 'never', 'unknown'];
  @override
  List<String> get symbols => JavaScript().symbols;
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  final stringLiteral =
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|`(?:[^`\\\\]|\\\\.)*`');
}

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

class CSS extends Language {
  @override
  String get name => 'CSS';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => ['import', 'media', 'from', 'to', 'important'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['{', '}', ':', ';', ',', '.', '#', '@'];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral =>
      RegExp(r'\b\d*\.?\d+(%|px|em|rem|vh|vw|pt|pc)?\b');
}

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

class Java extends BraceBasedLanguage {
  @override
  String get name => 'Java';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'abstract',
        'class',
        'extends',
        'implements',
        'interface',
        'public',
        'private',
        'protected',
        'static',
        'final',
        'void',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'throws',
        'new',
        'return',
        'break',
        'continue',
        'instanceof'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'boolean',
        'char',
        'byte',
        'short',
        'String',
        'Object'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '?',
        '!'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
}

class Kotlin extends BraceBasedLanguage {
  @override
  String get name => 'Kotlin';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'fun',
        'val',
        'var',
        'class',
        'interface',
        'object',
        'suspend',
        'when',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'return',
        'continue',
        'break',
        'as',
        'is',
        'in',
        'out',
        'super',
        'this'
      ];
  @override
  List<String> get types => [
        'Int',
        'Long',
        'Float',
        'Double',
        'Boolean',
        'Char',
        'String',
        'Array',
        'List',
        'Map'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '?',
        '!!'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|"""[\s\S]*?""")');
}

class CPP extends BraceBasedLanguage {
  @override
  String get name => 'C++';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'class',
        'struct',
        'template',
        'typename',
        'namespace',
        'using',
        'public',
        'private',
        'protected',
        'virtual',
        'override',
        'const',
        'static',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'throw',
        'new',
        'delete'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'bool',
        'char',
        'void',
        'auto',
        'string',
        'vector'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '::',
        '->',
        '<<',
        '>>'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');
}

class Rust extends BraceBasedLanguage {
  @override
  String get name => 'Rust';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'fn',
        'let',
        'mut',
        'pub',
        'struct',
        'enum',
        'trait',
        'impl',
        'use',
        'mod',
        'match',
        'if',
        'else',
        'for',
        'while',
        'loop',
        'return',
        'break',
        'continue',
        'unsafe'
      ];
  @override
  List<String> get types => [
        'i32',
        'i64',
        'u32',
        'u64',
        'f32',
        'f64',
        'bool',
        'char',
        'str',
        'String',
        'Vec',
        'Option',
        'Result'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '::',
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|r#"[^"]*"#)');
}

class Swift extends BraceBasedLanguage {
  @override
  String get name => 'Swift';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'func',
        'var',
        'let',
        'class',
        'struct',
        'enum',
        'protocol',
        'extension',
        'if',
        'else',
        'guard',
        'switch',
        'case',
        'for',
        'while',
        'return',
        'throw',
        'try',
        'catch'
      ];
  @override
  List<String> get types => [
        'Int',
        'Double',
        'Float',
        'Bool',
        'String',
        'Character',
        'Array',
        'Dictionary',
        'Set',
        'Any'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|"""[\s\S]*?""")');
}

class Ruby extends IndentationBasedLanguage {
  @override
  String get name => 'Ruby';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'def',
        'class',
        'module',
        'if',
        'else',
        'elsif',
        'unless',
        'case',
        'when',
        'while',
        'until',
        'for',
        'begin',
        'rescue',
        'ensure',
        'end',
        'yield',
        'return'
      ];
  @override
  List<String> get types => [
        'Integer',
        'Float',
        'String',
        'Array',
        'Hash',
        'Symbol',
        'NilClass',
        'TrueClass',
        'FalseClass'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '=>',
        '<<'
      ];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '%[qQ]?{(?:[^{}\\\\]|\\\\.)*}');
}

class PHP extends BraceBasedLanguage {
  @override
  String get name => 'PHP';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'function',
        'class',
        'interface',
        'trait',
        'extends',
        'implements',
        'public',
        'private',
        'protected',
        'if',
        'else',
        'elseif',
        'foreach',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw'
      ];
  @override
  List<String> get types => [
        'int',
        'float',
        'string',
        'bool',
        'array',
        'object',
        'null',
        'resource',
        'callable'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '===',
        '!=',
        '!==',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '=>',
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'(?://.*|#.*)');
  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');
}

class XML extends Language {
  @override
  String get name => 'XML';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['<', '>', '/', '=', '?'];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp(r'<!--[\s\S]*?-->');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
}

class JSON extends Language {
  @override
  String get name => 'JSON';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => ['true', 'false', 'null'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['{', '}', '[', ']', ':', ','];
  @override
  RegExp get commentSingle => RegExp('');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
  @override
  RegExp get numberLiteral => RegExp(r'-?\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

class TOML extends Language {
  @override
  String get name => 'TOML';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => ['true', 'false'];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => ['[', ']', '=', '.', ','];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '"""[\\s\\S]*?"""');
  @override
  RegExp get numberLiteral => RegExp(r'-?\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

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

class SQL extends Language {
  @override
  String get name => 'SQL';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'SELECT',
        'FROM',
        'WHERE',
        'INSERT',
        'UPDATE',
        'DELETE',
        'CREATE',
        'ALTER',
        'DROP',
        'TABLE',
        'INDEX',
        'JOIN',
        'GROUP',
        'BY',
        'HAVING',
        'ORDER',
        'LIMIT'
      ];
  @override
  List<String> get types => [
        'INTEGER',
        'VARCHAR',
        'TEXT',
        'DATE',
        'TIMESTAMP',
        'BOOLEAN',
        'FLOAT',
        'DOUBLE',
        'DECIMAL'
      ];
  @override
  List<String> get symbols => [
        '=',
        '<',
        '>',
        '<=',
        '>=',
        '!=',
        '(',
        ')',
        ',',
        '.',
        ';',
        '*',
        '+',
        '-',
        '/'
      ];
  @override
  RegExp get commentSingle => RegExp(r'--.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}

class R extends Language {
  @override
  String get name => 'R';
  @override
  String get toLowerCase => name.toLowerCase();
  @override
  List<String> get keywords => [
        'if',
        'else',
        'repeat',
        'while',
        'function',
        'for',
        'in',
        'next',
        'break',
        'TRUE',
        'FALSE',
        'NULL',
        'Inf',
        'NaN'
      ];
  @override
  List<String> get types => [
        'numeric',
        'integer',
        'complex',
        'logical',
        'character',
        'factor',
        'list',
        'matrix'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '^',
        '=',
        '<-',
        '->',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        '\$',
        '@',
        ':',
        ','
      ];
  @override
  RegExp get commentSingle => RegExp(r'#.*');
  @override
  RegExp get commentMulti => RegExp('');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

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

class Lua extends BraceBasedLanguage {
  @override
  String get name => 'Lua';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'and',
        'break',
        'do',
        'else',
        'elseif',
        'end',
        'false',
        'for',
        'function',
        'if',
        'in',
        'local',
        'nil',
        'not',
        'or',
        'repeat',
        'return',
        'then',
        'true',
        'until',
        'while'
      ];
  @override
  List<String> get types => [
        'nil',
        'number',
        'string',
        'boolean',
        'table',
        'function',
        'userdata',
        'thread'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '^',
        '#',
        '==',
        '~=',
        '<=',
        '>=',
        '<',
        '>',
        '=',
        '(',
        ')',
        '{',
        '}',
        '[',
        ']',
        ';',
        ':',
        ',',
        '.',
        '..'
      ];
  @override
  RegExp get commentSingle => RegExp(r'--.*');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
}

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

class Svelte extends Language {
  @override
  String get name => 'Svelte';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'script',
        'style',
        'if',
        'else',
        'each',
        'await',
        'then',
        'catch',
        'as',
        'export',
        'let',
        'const'
      ];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols =>
      ['<', '>', '/', '=', '{', '}', '(', ')', '[', ']', '#', ':', '@', '|'];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
  @override
  RegExp get stringLiteral => RegExp('["\'][^"\']*["\']');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+\b');
}

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

class C extends BraceBasedLanguage {
  @override
  String get name => 'C';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'if',
        'else',
        'for',
        'while',
        'do',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'goto',
        'typedef',
        'struct',
        'enum',
        'union',
        'sizeof'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'char',
        'void',
        'unsigned',
        'signed',
        'short',
        'const'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '->'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'"(?:[^"\\]|\\.)*"');
}

class CSharp extends BraceBasedLanguage {
  @override
  String get name => 'C#';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'class',
        'interface',
        'namespace',
        'using',
        'public',
        'private',
        'protected',
        'internal',
        'static',
        'async',
        'await',
        'if',
        'else',
        'for',
        'foreach',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'throw',
        'new',
        'return'
      ];
  @override
  List<String> get types => [
        'int',
        'long',
        'float',
        'double',
        'bool',
        'char',
        'string',
        'object',
        'dynamic',
        'var'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '=>',
        '??'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp stringLiteral = RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '@"[^"]*"');
}

class Go extends BraceBasedLanguage {
  @override
  String get name => 'Go';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'func',
        'interface',
        'struct',
        'type',
        'package',
        'import',
        'if',
        'else',
        'for',
        'range',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'go',
        'chan',
        'defer',
        'select'
      ];
  @override
  List<String> get types => [
        'int',
        'int64',
        'float64',
        'bool',
        'string',
        'error',
        'interface{}',
        'byte',
        'rune'
      ];
  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        ':=',
        '...'
      ];
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get stringLiteral => RegExp(r'(?:"(?:[^"\\]|\\.)*"|`[^`]*`)');
}

class Python extends IndentationBasedLanguage {
  @override
  String get name => 'Python';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'def',
        'class',
        'if',
        'else',
        'elif',
        'for',
        'while',
        'try',
        'except',
        'finally',
        'with',
        'as',
        'import',
        'from',
        'return',
        'yield',
        'break',
        'continue',
        'pass',
        'raise',
        'True',
        'False',
        'None',
        'and',
        'or',
        'not',
        'is',
        'in',
        'lambda',
        'nonlocal',
        'global',
        'assert',
        'async',
        'await'
      ];

  @override
  List<String> get types => [
        'int',
        'float',
        'str',
        'bool',
        'list',
        'dict',
        'tuple',
        'set',
        'bytes',
        'object'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '!=',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';'
      ];

  @override
  RegExp get commentSingle => RegExp(r'#.*');

  @override
  RegExp get commentMulti =>
      RegExp('(?:"""[\\s\\S]*?"""|\'\'\'[\\s\\S]*?\'\'\')');

  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

class JavaScript extends BraceBasedLanguage {
  @override
  String get name => 'JavaScript';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [
        'function',
        'class',
        'if',
        'else',
        'for',
        'while',
        'do',
        'try',
        'catch',
        'finally',
        'switch',
        'case',
        'break',
        'continue',
        'return',
        'throw',
        'const',
        'let',
        'var',
        'new',
        'this',
        'super',
        'extends',
        'null',
        'undefined',
        'true',
        'false',
        'async',
        'await',
        'yield',
        'typeof',
        'instanceof',
        'in'
      ];

  @override
  List<String> get types => [
        'number',
        'string',
        'boolean',
        'object',
        'symbol',
        'bigint',
        'undefined',
        'null'
      ];

  @override
  List<String> get symbols => [
        '+',
        '-',
        '*',
        '/',
        '%',
        '=',
        '==',
        '===',
        '!=',
        '!==',
        '<',
        '>',
        '<=',
        '>=',
        '(',
        ')',
        '[',
        ']',
        '{',
        '}',
        ':',
        ',',
        '.',
        ';',
        '=>',
        '...'
      ];

  @override
  RegExp get commentSingle => RegExp(r'//.*');

  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');

  @override
  RegExp get stringLiteral =>
      RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']|' '`(?:[^`\\\\]|\\\\.)*`');

  @override
  RegExp get numberLiteral =>
      RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b|0[xX][0-9a-fA-F]+\b');
}

class YAML extends IndentationBasedLanguage {
  @override
  String get name => 'YAML';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords =>
      ['true', 'false', 'null', 'yes', 'no', 'on', 'off'];

  @override
  List<String> get types => []; // YAML doesn't have explicit types

  @override
  List<String> get symbols =>
      [':', '-', '>', '|', '&', '*', '!', '?', '%', '@', '`'];

  @override
  RegExp get commentSingle => RegExp(r'#.*');

  @override
  RegExp get commentMulti =>
      RegExp(r''); // YAML doesn't have multi-line comments

  @override
  RegExp get stringLiteral => RegExp('["\'](?:[^"\'\\\\]|\\\\.)*["\']');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

class Markdown extends IndentationBasedLanguage {
  @override
  String get name => 'Markdown';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => []; // Markdown doesn't have traditional keywords

  @override
  List<String> get types => []; // Markdown doesn't have types

  @override
  List<String> get symbols =>
      ['#', '*', '_', '`', '~', '>', '-', '+', '=', '[', ']', '(', ')', '|'];

  @override
  RegExp get commentSingle => RegExp(r'<!--.*-->');

  @override
  RegExp get commentMulti => RegExp(r'<!--[\s\S]*?-->');

  @override
  RegExp get stringLiteral => RegExp(r'`[^`]*`');

  @override
  RegExp get numberLiteral => RegExp(r'\b\d*\.?\d+([eE][-+]?\d+)?\b');
}

// Fallback language for unknown file types
class UnknownLanguage extends Language {
  @override
  String get name => 'Unknown';
  @override
  String get toLowerCase => name.toLowerCase();

  @override
  List<String> get keywords => [];
  @override
  List<String> get types => [];
  @override
  List<String> get symbols => [];
  @override
  bool get usesIndentationFolding => false;
  @override
  RegExp get stringLiteral => RegExp(r'".*?"');
  @override
  RegExp get numberLiteral => RegExp(r'\b\d+\b');
  @override
  RegExp get commentSingle => RegExp(r'//.*');
  @override
  RegExp get commentMulti => RegExp(r'/\*[\s\S]*?\*/');
}
