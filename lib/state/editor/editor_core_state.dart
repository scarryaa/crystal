import 'package:crystal/models/editor/breadcrumb_item.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/command_palette_service.dart';
import 'package:crystal/services/editor/breadcrumb_generator.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_event_emitter.dart';
import 'package:crystal/services/editor/editor_file_manager.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:crystal/utils/utils.dart';
import 'package:flutter/material.dart' hide TextRange;
import 'package:path/path.dart' as p;

class EditorCoreState extends ChangeNotifier {
  // Core Properties
  final String id = UniqueKey().toString();
  final String path;
  final String? relativePath;
  final Buffer buffer;
  final VoidCallback resetGutterScroll;
  final EditorFileManager fileManager;
  final EditorEventEmitter eventEmitter;
  final EditorCursorManager cursorManager;

  // State Properties
  bool isDirty = false;
  bool isPinned = false;
  Language? detectedLanguage;
  List<BreadcrumbItem> breadcrumbs = [];

  // Constants
  final Set<String> indentationBasedLanguages = {
    'python',
    'yaml',
    'yml',
    'pug',
    'sass',
    'haml',
    'markdown',
    'gherkin',
    'nim'
  };

  EditorCoreState._({
    required this.path,
    required this.relativePath,
    required this.resetGutterScroll,
    required this.buffer,
    required this.fileManager,
    required this.eventEmitter,
    required this.cursorManager,
  }) {
    _initializeLanguage();
  }

  // Factory constructor
  factory EditorCoreState({
    String? path,
    String? relativePath,
    required VoidCallback resetGutterScroll,
    required Buffer buffer,
    required EditorFileManager fileManager,
    required EditorEventEmitter eventEmitter,
    required EditorCursorManager cursorManager,
  }) {
    return EditorCoreState._(
      path: path ?? generateUniqueTempPath(),
      relativePath: relativePath,
      resetGutterScroll: resetGutterScroll,
      buffer: buffer,
      fileManager: fileManager,
      eventEmitter: eventEmitter,
      cursorManager: cursorManager,
    );
  }

  // File Operations
  Future<void> save() async {
    if (path.isEmpty || path.substring(0, 6) == '__temp') {
      await saveFileAs(path);
    } else {
      await saveFile(path);
    }
    buffer.isDirty = false;
    notifyListeners();
  }

  Future<bool> saveFile(String path) async {
    try {
      final success = await fileManager.saveFile(path);
      if (success) {
        buffer.isDirty = false;
        eventEmitter.emitFileChangedEvent();
        notifyListeners();
      }
      return success;
    } catch (e) {
      eventEmitter.emitErrorEvent('Failed to save file', path, e.toString());
      return false;
    }
  }

  Future<bool> saveFileAs(String path) async {
    try {
      final success = await fileManager.saveFileAs(path);
      if (success) {
        buffer.isDirty = false;
        eventEmitter.emitFileChangedEvent();
        notifyListeners();
      }
      return success;
    } catch (e) {
      eventEmitter.emitErrorEvent('Failed to save file', path, e.toString());
      return false;
    }
  }

  void openFile(String content) {
    buffer.setContent(content);
    cursorManager.reset();
    fileManager.openFile(content);
    isDirty = false;
    resetGutterScroll();
    _initializeLanguage();
    updateBreadcrumbs(0, 0);
    eventEmitter.emitFileChangedEvent();

    if (path.isNotEmpty && !path.startsWith('__temp')) {
      CommandPaletteService.addRecentFile(path);
    }
    notifyListeners();
  }

  // Buffer Operations
  bool get isEmpty => buffer.isEmpty;
  String getLine(int line) => buffer.getLine(line);
  void setLine(int line, String content) => buffer.setLine(line, content);
  String getTextInRange(TextRange range) => buffer.getTextInRange(range);

  // Language Operations
  void _initializeLanguage() {
    final filename = path.isNotEmpty ? p.split(path).last : '';
    detectedLanguage =
        LanguageDetectionService.getLanguageFromFilename(filename);
  }

  bool isIndentationBasedLanguage(String? language) {
    return language != null &&
        indentationBasedLanguages.contains(language.toLowerCase());
  }

  // Breadcrumb Operations
  void updateBreadcrumbs(int line, int column) {
    if (!path.toLowerCase().endsWith('.dart')) {
      breadcrumbs = [];
      return;
    }

    String sourceCode = buffer.lines.join('\n');
    int cursorOffset = _calculateCursorOffset(sourceCode, line, column);
    breadcrumbs =
        BreadcrumbGenerator().generateBreadcrumbs(sourceCode, cursorOffset);
    notifyListeners();
  }

  int _calculateCursorOffset(String sourceCode, int line, int column) {
    List<String> lines = sourceCode.split('\n');
    int offset = 0;
    for (int i = 0; i < line; i++) {
      offset += lines[i].length + 1;
    }
    return offset + column;
  }
}
