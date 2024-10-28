import 'package:crystal/state/editor_scroll_state.dart';
import 'package:flutter/material.dart';

class EditorState extends ChangeNotifier {
  int version = 1;
  List<String> lines = [''];
  int cursorLine = 0;
  int cursorColumn = 0;
  EditorScrollState scrollState = EditorScrollState();

  void insertChar(String c) {
    lines[cursorLine] = lines[cursorLine].substring(0, cursorColumn) +
        c +
        lines[cursorLine].substring(cursorColumn);
    cursorColumn++;
    version++;
    notifyListeners();
  }
}
