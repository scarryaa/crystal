import 'package:crystal/services/editor/editor_scroll_manager.dart';
import 'package:crystal/services/editor/editor_tab_manager.dart';
import 'package:crystal/widgets/editor/editor_view.dart';
import 'package:flutter/material.dart';

class EditorStateProvider extends ChangeNotifier {
  final Map<String, GlobalKey<EditorViewState>> _editorViewKeys = {};
  final EditorTabManager editorTabManager;
  final Map<String, EditorScrollManager> _scrollManagers = {};
  final Map<String, GlobalKey> _tabBarKeys = {};
  final Map<String, ScrollController> _tabBarScrollControllers = {};

  EditorStateProvider({required this.editorTabManager});

  String _getKey(int row, int col) => '${row}_$col';

  int getSplitIndex(int row, int col) {
    int index = 0;
    for (int i = 0; i < row; i++) {
      if (i >= editorTabManager.horizontalSplits.length) break;
      index += editorTabManager.horizontalSplits[i].length;
    }
    return index + col;
  }

  GlobalKey<EditorViewState> getEditorViewKey(int row, int col) {
    final key = _getKey(row, col);
    return _editorViewKeys.putIfAbsent(
      key,
      () => GlobalKey<EditorViewState>(),
    );
  }

  EditorScrollManager getScrollManager(int row, int col) {
    final key = _getKey(row, col);
    if (!_scrollManagers.containsKey(key)) {
      final scrollManager = EditorScrollManager();
      scrollManager.initListeners(
        onEditorScroll: () => handleEditorScroll(row, col),
        onGutterScroll: () => handleGutterScroll(row, col),
      );
      _scrollManagers[key] = scrollManager;
    }
    return _scrollManagers[key]!;
  }

  void handleEditorScroll(int row, int col) {
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = getScrollManager(row, col);
    final activeEditor =
        editorTabManager.horizontalSplits[row][col].activeEditor;

    if (activeEditor == null) return;

    if (scrollManager.gutterScrollController.offset !=
        scrollManager.editorVerticalScrollController.offset) {
      scrollManager.gutterScrollController
          .jumpTo(scrollManager.editorVerticalScrollController.offset);
      activeEditor.updateVerticalScrollOffset(
          scrollManager.editorVerticalScrollController.offset);
    }

    activeEditor.updateHorizontalScrollOffset(
        scrollManager.editorHorizontalScrollController.offset);
  }

  void handleGutterScroll(int row, int col) {
    if (row >= editorTabManager.horizontalSplits.length ||
        col >= editorTabManager.horizontalSplits[row].length) {
      return;
    }

    final scrollManager = getScrollManager(row, col);
    final activeEditor =
        editorTabManager.horizontalSplits[row][col].activeEditor;

    if (activeEditor == null) return;

    if (scrollManager.editorVerticalScrollController.offset !=
        scrollManager.gutterScrollController.offset) {
      scrollManager.editorVerticalScrollController
          .jumpTo(scrollManager.gutterScrollController.offset);
      activeEditor.updateVerticalScrollOffset(
          scrollManager.gutterScrollController.offset);
    }
  }

  ScrollController getTabBarScrollController(int row, int col) {
    final key = _getKey(row, col);
    if (!_tabBarScrollControllers.containsKey(key)) {
      _tabBarScrollControllers[key] = ScrollController();
    }
    return _tabBarScrollControllers[key]!;
  }

  GlobalKey getTabBarKey(int row, int col) {
    final key = _getKey(row, col);
    return _tabBarKeys.putIfAbsent(key, () => GlobalKey());
  }

  @override
  void dispose() {
    _scrollManagers.forEach((_, manager) => manager.dispose());
    _scrollManagers.clear();

    for (final scrollController in _tabBarScrollControllers.values) {
      scrollController.dispose();
    }
    _tabBarScrollControllers.clear();

    _editorViewKeys.clear();
    _tabBarKeys.clear();

    super.dispose();
  }
}
