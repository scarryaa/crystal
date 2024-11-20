import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/text_range.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/selection_manager.dart';
import 'package:crystal/services/git_service.dart';

class EditorEventEmitter {
  final SelectionManager selectionManager;
  final Buffer buffer;
  final String path;
  final String? relativePath;
  final String Function() getSelectedText;
  final GitService gitService;

  EditorEventEmitter({
    required this.selectionManager,
    required this.buffer,
    required this.path,
    required this.relativePath,
    required this.getSelectedText,
    required this.gitService,
  });

  void emitCursorChangedEvent({
    required List<Cursor> cursors,
    required int line,
    required int column,
  }) {
    EditorEventBus.emit(CursorEvent(
      cursors: cursors,
      line: line,
      column: column,
      hasSelection: selectionManager.hasSelection(),
      selections: selectionManager.selections,
    ));
  }

  void emitTextChangedEvent() {
    EditorEventBus.emit(TextEvent(
      content: buffer.toString(),
      isDirty: buffer.isDirty,
      path: path,
    ));

    if (path.isNotEmpty && !path.startsWith('__temp')) {
      gitService.updateDocumentChanges(relativePath ?? '', buffer.lines);
    }
  }

  void emitSelectionChangedEvent() {
    EditorEventBus.emit(SelectionEvent(
      selections: selectionManager.selections,
      hasSelection: selectionManager.hasSelection(),
      selectedText: getSelectedText(),
    ));
  }

  void emitFileChangedEvent() {
    EditorEventBus.emit(FileEvent(
      path: path,
      relativePath: relativePath,
      content: buffer.toString(),
      isDirty: buffer.isDirty,
    ));
  }

  void emitClipboardEvent(String text, ClipboardAction action) {
    EditorEventBus.emit(ClipboardEvent(
      text: text,
      action: action,
    ));
  }

  void emitErrorEvent(String message, [String? path, Object? error]) {
    EditorEventBus.emit(ErrorEvent(
      message: message,
      path: path,
      error: error,
    ));
  }

  void emitHoverEvent({
    required String content,
    required int line,
    required int character,
    required List<lsp_models.Diagnostic> diagnostics,
    TextRange? diagnosticRange,
  }) {
    EditorEventBus.emit(HoverEvent(
      content: content,
      line: line,
      character: character,
      diagnostics: diagnostics,
      diagnosticRange: diagnosticRange,
    ));
  }
}
