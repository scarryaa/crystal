import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
  final List<EditorState> _editors = [];
  int activeEditorIndex = -1;

  EditorState? get activeEditor =>
      _editors.isEmpty ? null : _editors[activeEditorIndex];
  List<EditorState> get editors => _editors;

  void addEditor(EditorState editor) {
    _editors.add(editor);
    activeEditorIndex = _editors.length - 1;
    notifyListeners();
  }

  void closeEditor(int index) {
    if (_editors.isEmpty || _editors[index].isPinned) {
      return;
    }

    _editors.removeAt(index);
    if (activeEditorIndex >= _editors.length) {
      activeEditorIndex = _editors.length - 1;
    }
    notifyListeners();
  }

  void setActiveEditor(int index) {
    if (index >= 0 && index < _editors.length) {
      activeEditorIndex = index;
    }
    notifyListeners();
  }

  void reorderEditor(int oldIndex, int newIndex) {
    final movingEditor = _editors[oldIndex];
    final pinnedCount = _editors.where((e) => e.isPinned).length;

    // Prevent moving unpinned tabs before pinned ones
    if (!movingEditor.isPinned && newIndex < pinnedCount) {
      newIndex = pinnedCount;
    }

    // Prevent moving pinned tabs after unpinned ones
    if (movingEditor.isPinned && newIndex > pinnedCount - 1) {
      newIndex = pinnedCount - 1;
    }

    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    final item = editors.removeAt(oldIndex);
    editors.insert(newIndex, item);

    // Update activeEditorIndex
    if (activeEditorIndex == oldIndex) {
      activeEditorIndex = newIndex;
    } else if (activeEditorIndex > oldIndex && activeEditorIndex <= newIndex) {
      activeEditorIndex--;
    } else if (activeEditorIndex < oldIndex && activeEditorIndex >= newIndex) {
      activeEditorIndex++;
    }
    notifyListeners();
  }

  void togglePin(int index) {
    editors[index].isPinned = !editors[index].isPinned;

    if (editors[index].isPinned) {
      int pinnedCount = editors.where((e) => e.isPinned).length - 1;
      if (index > pinnedCount) {
        final editor = editors.removeAt(index);
        editors.insert(pinnedCount, editor);
        if (activeEditorIndex == index) {
          activeEditorIndex = pinnedCount;
        }
      }
    }
    notifyListeners();
  }
}
