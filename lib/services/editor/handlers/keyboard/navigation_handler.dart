import 'package:crystal/models/editor/commands/navigation_commands.dart';
import 'package:crystal/services/editor/handlers/keyboard/keyboard_handler_base.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NavigationHandler extends KeyboardHandlerBase {
  final NavigationCommands navigationCommands;

  NavigationHandler({
    required EditorState Function() getState,
    required VoidCallback scrollToCursor,
    required this.navigationCommands,
  }) : super(
          getState,
          scrollToCursor,
        );

  KeyEventResult handleNavigation(
      LogicalKeyboardKey key, bool isShiftPressed, bool isControlPressed) {
    switch (key) {
      case LogicalKeyboardKey.arrowDown:
        navigationCommands.moveCursorDown(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowUp:
        navigationCommands.moveCursorUp(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowLeft:
        navigationCommands.moveCursorLeft(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.arrowRight:
        navigationCommands.moveCursorRight(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.home:
        if (isControlPressed) {
          navigationCommands.moveCursorToDocumentStart(isShiftPressed);
        } else {
          navigationCommands.moveCursorToLineStart(isShiftPressed);
        }
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.end:
        if (isControlPressed) {
          navigationCommands.moveCursorToDocumentEnd(isShiftPressed);
        } else {
          navigationCommands.moveCursorToLineEnd(isShiftPressed);
        }
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.pageUp:
        navigationCommands.moveCursorPageUp(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      case LogicalKeyboardKey.pageDown:
        navigationCommands.moveCursorPageDown(isShiftPressed);
        scrollToCursor();
        return KeyEventResult.handled;

      default:
        return KeyEventResult.ignored;
    }
  }
}
