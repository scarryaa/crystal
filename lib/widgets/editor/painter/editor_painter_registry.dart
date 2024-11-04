import 'dart:ui';

import 'package:crystal/widgets/editor/painter/painters/editor_painter_base.dart';

class EditorPainterRegistry {
  final List<EditorPainterBase> _painters = [];

  void register(EditorPainterBase painter) {
    _painters.add(painter);
  }

  void clear() {
    _painters.clear();
  }

  void paintAll(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  }) {
    for (final painter in _painters) {
      painter.paint(
        canvas,
        size,
        firstVisibleLine: firstVisibleLine,
        lastVisibleLine: lastVisibleLine,
      );
    }
  }

  bool shouldRepaint(EditorPainterRegistry oldRegistry) {
    if (_painters.length != oldRegistry._painters.length) return true;

    for (int i = 0; i < _painters.length; i++) {
      if (_painters[i].shouldRepaint(oldRegistry._painters[i])) {
        return true;
      }
    }

    return false;
  }
}
