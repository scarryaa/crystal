import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_event_emitter.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';
import 'package:crystal/services/editor/undo_redo_manager.dart';
import 'package:crystal/services/git_service.dart';

class TextController {
  final Buffer buffer;
  final EditorEventEmitter eventEmitter;
  final TextManipulator textManipulator;
  final UndoRedoManager undoRedoManager;
  final GitService gitService;

  TextController({
    required this.buffer,
    required this.eventEmitter,
    required this.textManipulator,
    required this.undoRedoManager,
    required this.gitService,
  });

  void insertNewLine() {
    textManipulator.insertChar('\n');
    _emitTextChangedEvent();
  }

  void insertChar(String char) {
    textManipulator.insertChar(char);
    _emitTextChangedEvent();
  }

  void backspace() {
    textManipulator.backspace();
    _emitTextChangedEvent();
  }

  void delete() {
    textManipulator.delete();
    _emitTextChangedEvent();
  }

  void insertTab() {
    textManipulator.insertChar('  ');
    _emitTextChangedEvent();
  }

  void backTab() {
    textManipulator.backTab();
    _emitTextChangedEvent();
  }

  void undo() {
    undoRedoManager.undo();
    _emitTextChangedEvent();
  }

  void redo() {
    undoRedoManager.redo();
    _emitTextChangedEvent();
  }

  void _emitTextChangedEvent() {
    eventEmitter.emitTextChangedEvent();
  }
}
