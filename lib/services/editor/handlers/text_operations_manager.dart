import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/handlers/text_manipulator.dart';

class TextOperationsManager {
  final Buffer buffer;
  final TextManipulator textManipulator;
  final Function() onTextChanged;
  final Function() updateCompletions;

  TextOperationsManager({
    required this.buffer,
    required this.textManipulator,
    required this.onTextChanged,
    required this.updateCompletions,
  });

  void insertNewLine() {
    textManipulator.insertNewLine();
    updateCompletions();
    onTextChanged();
  }

  void backspace() {
    textManipulator.backspace();
    updateCompletions();
    onTextChanged();
  }

  void delete() {
    textManipulator.delete();
    updateCompletions();
    onTextChanged();
  }

  void insertChar(String c) {
    textManipulator.insertChar(c);
    updateCompletions();
    onTextChanged();
  }

  void insertTab() {
    textManipulator.insertTab();
    updateCompletions();
    onTextChanged();
  }

  void backTab() {
    textManipulator.backTab();
    updateCompletions();
    onTextChanged();
  }
}
