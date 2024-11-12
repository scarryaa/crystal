import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
  final List<SplitView> _splitViews = [SplitView()];
  int activeSplitViewIndex = 0;

  SplitView get activeSplitView => _splitViews[activeSplitViewIndex];
  List<SplitView> get splitViews => _splitViews;

  EditorState? get activeEditor => activeSplitView.activeEditor;
  List<EditorState> get editors => activeSplitView.editors;

  void addSplitView({bool vertical = true}) {
    if (activeEditor == null) return;

    // Create new split view
    final newSplitView = SplitView();

    // Create a new editor with copied state
    final newEditor = EditorState(
      editorConfigService: activeEditor!.editorConfigService,
      editorLayoutService: activeEditor!.editorLayoutService,
      path: activeEditor!.path,
      relativePath: activeEditor!.relativePath,
      tapCallback: activeEditor!.tapCallback,
      resetGutterScroll: activeEditor!.resetGutterScroll,
    );

    // Copy the content and initial cursor/selection state
    newEditor.openFile(activeEditor!.buffer.content);
    newEditor.editorCursorManager
        .setAllCursors(List.from(activeEditor!.editorCursorManager.cursors));
    newEditor.editorSelectionManager.setAllSelections(
        List.from(activeEditor!.editorSelectionManager.selections));

    // Add the editor to new split view
    newSplitView.editors.add(newEditor);
    newSplitView.activeEditorIndex = 0;

    // Add the split view
    _splitViews.add(newSplitView);
    activeSplitViewIndex = _splitViews.length - 1;

    notifyListeners();
  }

  void closeSplitView(int index) {
    if (_splitViews.length <= 1) return;
    _splitViews.removeAt(index);
    if (activeSplitViewIndex >= _splitViews.length) {
      activeSplitViewIndex = _splitViews.length - 1;
    }
    notifyListeners();
  }

  void setActiveSplitView(int index) {
    if (index >= 0 && index < _splitViews.length) {
      activeSplitViewIndex = index;
      notifyListeners();
    }
  }

  void addEditor(EditorState editor, {int? splitViewIndex}) {
    final targetView = splitViewIndex != null
        ? _splitViews[splitViewIndex]
        : _splitViews[activeSplitViewIndex];

    targetView.editors.add(editor);
    targetView.activeEditorIndex = targetView.editors.length - 1;

    // Focus the split view that received the new editor
    if (splitViewIndex != null) {
      activeSplitViewIndex = splitViewIndex;
    }

    notifyListeners();
  }

  void focusSplitView(int index) {
    if (index >= 0 && index < _splitViews.length) {
      activeSplitViewIndex = index;
      notifyListeners();
    }
  }

  void closeEditor(int index, {int? splitViewIndex}) {
    final targetView =
        splitViewIndex != null ? _splitViews[splitViewIndex] : activeSplitView;

    if (targetView.editors.isEmpty || targetView.editors[index].isPinned) {
      return;
    }

    targetView.editors.removeAt(index);
    if (targetView.activeEditorIndex >= targetView.editors.length) {
      targetView.activeEditorIndex = targetView.editors.length - 1;
    }
    notifyListeners();
  }

  void setActiveEditor(int index, {int? splitViewIndex}) {
    final targetView =
        splitViewIndex != null ? _splitViews[splitViewIndex] : activeSplitView;

    if (index >= 0 && index < targetView.editors.length) {
      targetView.activeEditorIndex = index;
      notifyListeners();
    }
  }

  void reorderEditor(int oldIndex, int newIndex, {int? splitViewIndex}) {
    final targetView =
        splitViewIndex != null ? _splitViews[splitViewIndex] : activeSplitView;

    final movingEditor = targetView.editors[oldIndex];
    final pinnedCount = targetView.editors.where((e) => e.isPinned).length;

    if (!movingEditor.isPinned && newIndex < pinnedCount) {
      newIndex = pinnedCount;
    }

    if (movingEditor.isPinned && newIndex > pinnedCount - 1) {
      newIndex = pinnedCount - 1;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = targetView.editors.removeAt(oldIndex);
    targetView.editors.insert(newIndex, item);

    if (targetView.activeEditorIndex == oldIndex) {
      targetView.activeEditorIndex = newIndex;
    } else if (targetView.activeEditorIndex > oldIndex &&
        targetView.activeEditorIndex <= newIndex) {
      targetView.activeEditorIndex--;
    } else if (targetView.activeEditorIndex < oldIndex &&
        targetView.activeEditorIndex >= newIndex) {
      targetView.activeEditorIndex++;
    }
    notifyListeners();
  }

  void togglePin(int index, {int? splitViewIndex}) {
    final targetView =
        splitViewIndex != null ? _splitViews[splitViewIndex] : activeSplitView;

    targetView.editors[index].isPinned = !targetView.editors[index].isPinned;

    if (targetView.editors[index].isPinned) {
      int pinnedCount = targetView.editors.where((e) => e.isPinned).length - 1;
      if (index > pinnedCount) {
        final editor = targetView.editors.removeAt(index);
        targetView.editors.insert(pinnedCount, editor);
        if (targetView.activeEditorIndex == index) {
          targetView.activeEditorIndex = pinnedCount;
        }
      }
    }
    notifyListeners();
  }
}
