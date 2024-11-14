import 'package:crystal/models/editor/command.dart';

class UndoRedoManager {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  void executeCommand(Command command) {
    command.execute();
    _undoStack.add(command);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    Command command = _undoStack.removeLast();
    command.undo();
    _redoStack.add(command);
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    Command command = _redoStack.removeLast();
    command.execute();
    _undoStack.add(command);
  }

  Command getLastUndo() {
    return _undoStack.last;
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;
}
