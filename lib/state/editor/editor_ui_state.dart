import 'dart:async';

import 'package:crystal/models/editor/position.dart';
import 'package:crystal/state/editor/editor_scroll_state.dart';

class UIState {
  EditorScrollState scrollState = EditorScrollState();
  bool isHoverInfoVisible = false;

  // UI-related methods
  void updateScrollState(double vertical, double horizontal) {
    scrollState.updateVerticalScrollOffset(vertical);
    scrollState.updateHorizontalScrollOffset(horizontal);
  }
}
