import 'dart:ui';

import 'package:crystal/state/editor/editor_state.dart';

class KeyboardHandlerBase {
  final EditorState Function() getState;
  final VoidCallback scrollToCursor;

  KeyboardHandlerBase(this.getState, this.scrollToCursor);
}
