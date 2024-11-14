import 'package:crystal/state/editor/editor_scroll_state.dart';

class ScrollHandler {
  EditorScrollState scrollState;
  Function() notifyListeners;

  ScrollHandler({required this.scrollState, required this.notifyListeners});

  void updateVerticalScrollOffset(double offset) {
    scrollState.updateVerticalScrollOffset(offset);
    notifyListeners();
  }

  void updateHorizontalScrollOffset(double offset) {
    scrollState.updateHorizontalScrollOffset(offset);
    notifyListeners();
  }
}
