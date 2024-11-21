import 'dart:async';

import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:flutter/material.dart';

class FocusManager {
  EditorViewConfig config;
  final FocusNode focusNode = FocusNode();
  bool isFocused = false;
  Timer? _caretTimer;

  FocusManager({
    required this.config,
  });

  bool get hasFocus => focusNode.hasFocus;

  void startCaretBlinking() {
    _caretTimer?.cancel();
    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      config.state.toggleCaret();
    });
  }

  void stopCaretBlinking() {
    _caretTimer?.cancel();
    _caretTimer = null;
  }

  void resetCaretBlink() {
    config.state.showCaret = true;
    startCaretBlinking();
  }

  void requestFocus() {
    focusNode.requestFocus();
  }

  void dispose() {
    focusNode.dispose();
  }
}
