import 'package:flutter/material.dart';

class GlobalHoverState extends ChangeNotifier {
  int? activeRow;
  int? activeCol;

  void setActiveEditor(int? row, int? col) {
    activeRow = row;
    activeCol = col;
    notifyListeners();
  }

  void clearActiveEditor() {
    activeRow = null;
    activeCol = null;
    notifyListeners();
  }

  bool isActive(int row, int col) {
    return activeRow == row && activeCol == col;
  }
}
