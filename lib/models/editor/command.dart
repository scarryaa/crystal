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

  TextInsertCommand(
      this.buffer, this.text, this.line, this.column, this.cursor);

  @override
  void execute() {
    String currentLine = buffer.getLine(line);
    String newContent =
        currentLine.substring(0, column) + text + currentLine.substring(column);
    buffer.setLine(line, newContent);
    cursor.column += text.length;
    buffer.incrementVersion();
  }

  @override
  void undo() {
    String currentLine = buffer.getLine(line);
    String newContent = currentLine.substring(0, column) +
        currentLine.substring(column + text.length);
    buffer.setLine(line, newContent);
    cursor.column -= text.length;
    buffer.incrementVersion();
  }
}

class TextDeleteCommand implements Command {
  final Buffer buffer;
  final int line;
  final int column;
  final String deletedText;
  final Cursor cursor;

  TextDeleteCommand(
      this.buffer, this.line, this.column, this.deletedText, this.cursor);

  @override
  void execute() {
    String currentLine = buffer.getLine(line);
    String newContent = currentLine.substring(0, column) +
        currentLine.substring(column + deletedText.length);
    buffer.setLine(line, newContent);
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
    cursor.column = column + deletedText.length;
    buffer.incrementVersion();
  }
}
