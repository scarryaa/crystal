import 'dart:ui';

class NavigationCommands {
  final VoidCallback scrollToCursor;
  final Function(bool isShiftPressed) moveCursorUp;
  final Function(bool isShiftPressed) moveCursorDown;
  final Function(bool isShiftPressed) moveCursorLeft;
  final Function(bool isShiftPressed) moveCursorRight;
  final Function(bool isShiftPressed) moveCursorToLineStart;
  final Function(bool isShiftPressed) moveCursorToLineEnd;
  final Function(bool isShiftPressed) moveCursorToDocumentStart;
  final Function(bool isShiftPressed) moveCursorToDocumentEnd;
  final Function(bool isShiftPressed) moveCursorPageUp;
  final Function(bool isShiftPressed) moveCursorPageDown;

  NavigationCommands({
    required this.scrollToCursor,
    required this.moveCursorUp,
    required this.moveCursorDown,
    required this.moveCursorLeft,
    required this.moveCursorRight,
    required this.moveCursorToLineStart,
    required this.moveCursorToLineEnd,
    required this.moveCursorToDocumentStart,
    required this.moveCursorToDocumentEnd,
    required this.moveCursorPageUp,
    required this.moveCursorPageDown,
  });
}
