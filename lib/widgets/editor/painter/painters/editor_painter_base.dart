import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:flutter/material.dart';

abstract class EditorPainterBase {
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  const EditorPainterBase({
    required this.editorLayoutService,
    required this.editorConfigService,
  });

  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  });

  bool shouldRepaint(EditorPainterBase oldDelegate) => false;
}
