class EditingCommands {
  final Function() copy;
  final Function() cut;
  final Function() paste;
  final Function() selectAll;
  final Function() backspace;
  final Function() delete;
  final Function() insertNewLine;
  final Function() insertTab;
  final Function() backTab;
  final Function(String character) insertChar;
  final Function() getLastPastedLineCount;
  final Function() getSelectedLineRange;

  EditingCommands({
    required this.copy,
    required this.cut,
    required this.paste,
    required this.selectAll,
    required this.backspace,
    required this.delete,
    required this.insertNewLine,
    required this.insertTab,
    required this.backTab,
    required this.insertChar,
    required this.getLastPastedLineCount,
    required this.getSelectedLineRange,
  });
}
