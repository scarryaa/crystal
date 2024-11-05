import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';

abstract class Command {
  void execute();
  void undo();
}

class TextInsertCommand implements Command {
  final Buffer buffer;
  final String text;
  final int line;
  final int column;
  final Cursor cursor;
  late final int _originalLine;
  late final int _originalColumn;

  TextInsertCommand(
      this.buffer, this.text, this.line, this.column, this.cursor) {
    // Store initial cursor state
    _originalLine = cursor.line;
    _originalColumn = cursor.column;
  }

  @override
  void execute() {
    String currentLine = buffer.getLine(line);
    String newContent =
        currentLine.substring(0, column) + text + currentLine.substring(column);
    buffer.setLine(line, newContent);
    cursor.line = line;
    cursor.column = column + text.length;
    buffer.incrementVersion();
  }

  @override
  void undo() {
    String currentLine = buffer.getLine(line);
    String newContent = currentLine.substring(0, column) +
        currentLine.substring(column + text.length);
    buffer.setLine(line, newContent);
    // Restore original cursor position
    cursor.line = _originalLine;
    cursor.column = _originalColumn;
    buffer.incrementVersion();
  }
}

class TextDeleteCommand implements Command {
  final Buffer buffer;
  final int line;
  final int column;
  final String deletedText;
  final Cursor cursor;
  late final int _originalLine;
  late final int _originalColumn;

  TextDeleteCommand(
      this.buffer, this.line, this.column, this.deletedText, this.cursor) {
    // Store initial cursor state
    _originalLine = cursor.line;
    _originalColumn = cursor.column;
  }

  @override
  void execute() {
    String currentLine = buffer.getLine(line);
    String newContent = currentLine.substring(0, column) +
        currentLine.substring(column + deletedText.length);
    buffer.setLine(line, newContent);
    cursor.line = line;
    cursor.column = column;
    buffer.incrementVersion();
  }

  @override
  void undo() {
    String currentLine = buffer.getLine(line);
    String newContent = currentLine.substring(0, column) +
        deletedText +
        currentLine.substring(column);
    buffer.setLine(line, newContent);
    // Restore original cursor position
    cursor.line = _originalLine;
    cursor.column = _originalColumn;
    buffer.incrementVersion();
  }
}
