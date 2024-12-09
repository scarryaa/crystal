import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/widgets/gutter/managers/gutter_mouse_manager.dart';
import 'package:flutter/material.dart';

class GutterInputManager {
  EditorCore core;
  late GutterMouseManager mouseManager;

  GutterInputManager(this.core) {
    mouseManager = GutterMouseManager(core);
  }

  void handleMouseEvent(
      Offset localPosition, Offset scrollPosition, PointerEvent event) {
    mouseManager.handleMouseEvent(event, localPosition, scrollPosition);
  }
}
