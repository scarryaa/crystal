import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:flutter/material.dart';

abstract class EditorPainterBase {
  final EditorLayoutService editorLayoutService;

  const EditorPainterBase({
    required this.editorLayoutService,
  });

  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  });

  bool shouldRepaint(EditorPainterBase oldDelegate) => false;
}
