import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
  final Function(int, int)? onSplitViewClosed;

  EditorTabManager({this.onSplitViewClosed});

  final List<List<SplitView>> _splitViews = [
    [SplitView()]
  ];
  int activeRow = 0;
  int activeCol = 0;

  List<List<SplitView>> get horizontalSplits => _splitViews;
  SplitView get activeSplitView => _splitViews[activeRow][activeCol];

  EditorState? get activeEditor => activeSplitView.activeEditor;
  List<EditorState> get editors => activeSplitView.editors;

  void addHorizontalSplit() {
    if (activeEditor == null) return;

    final newSplitView = SplitView();
    final newEditor = _copyEditorState(activeEditor!);
    newSplitView.editors.add(newEditor);
    newSplitView.activeEditorIndex = 0;

    _splitViews.add([newSplitView]);
    activeRow = _splitViews.length - 1;
    activeCol = 0;

    notifyListeners();
  }

  void addVerticalSplit() {
    if (activeEditor == null) return;

    final newSplitView = SplitView();
    final newEditor = _copyEditorState(activeEditor!);
    newSplitView.editors.add(newEditor);
    newSplitView.activeEditorIndex = 0;

    _splitViews[activeRow].add(newSplitView);
    activeCol = _splitViews[activeRow].length - 1;

    notifyListeners();
  }

  void closeSplitView(int row, int col) {
    // Don't close if it's the last split view
    if (_splitViews.length <= 1 && _splitViews[0].length <= 1) return;

    onSplitViewClosed?.call(row, col);

    if (row >= _splitViews.length || col >= _splitViews[row].length) return;
    _splitViews[row].removeAt(col);

    // If row becomes empty and it's not the last row, remove it
    if (_splitViews[row].isEmpty && _splitViews.length > 1) {
      _splitViews.removeAt(row);
    } else if (_splitViews[row].isEmpty) {
      _splitViews[row].add(SplitView());
    }

    // Adjust active indices to ensure they're valid
    activeRow = activeRow.clamp(0, _splitViews.length - 1);
    activeCol = activeCol.clamp(0, _splitViews[activeRow].length - 1);

    notifyListeners();
  }

  EditorState _copyEditorState(EditorState source) {
    final newEditor = EditorState(
      editorConfigService: source.editorConfigService,
      editorLayoutService: source.editorLayoutService,
      path: source.path,
      relativePath: source.relativePath,
      tapCallback: source.tapCallback,
      resetGutterScroll: source.resetGutterScroll,
    );

    newEditor.openFile(source.buffer.content);
    newEditor.editorCursorManager
        .setAllCursors(List.from(source.editorCursorManager.cursors));
    newEditor.editorSelectionManager
        .setAllSelections(List.from(source.editorSelectionManager.selections));

    return newEditor;
  }

  void focusSplitView(int row, int col) {
    if (row >= 0 &&
        row < _splitViews.length &&
        col >= 0 &&
        col < _splitViews[row].length) {
      activeRow = row;
      activeCol = col;
      notifyListeners();
    }
  }

  void addEditor(EditorState editor, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;

    if (targetRow < 0 ||
        targetRow >= _splitViews.length ||
        targetCol < 0 ||
        targetCol >= _splitViews[targetRow].length) {
      return;
    }

    final targetView = _splitViews[targetRow][targetCol];
    targetView.editors.add(editor);
    targetView.activeEditorIndex = targetView.editors.length - 1;

    if (row != null && col != null) {
      focusSplitView(row, col);
    }

    notifyListeners();
  }

  void closeEditor(int index, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;
    final targetView = _splitViews[targetRow][targetCol];

    if (targetView.editors.isEmpty || targetView.editors[index].isPinned) {
      return;
    }

    targetView.editors.removeAt(index);

    // Only call closeSplitView if there are no editors left
    if (targetView.editors.isEmpty) {
      closeSplitView(targetRow, targetCol);
    } else {
      if (targetView.activeEditorIndex >= targetView.editors.length) {
        targetView.activeEditorIndex = targetView.editors.length - 1;
      } else if (targetView.activeEditorIndex == index) {
        // If we closed the active editor, select the next one
        targetView.activeEditorIndex =
            index.clamp(0, targetView.editors.length - 1);
      }
    }

    notifyListeners();
  }

  void setActiveEditor(int index, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;

    // Validate indices first
    if (targetRow >= _splitViews.length ||
        targetCol >= _splitViews[targetRow].length) {
      return;
    }

    final targetView = _splitViews[targetRow][targetCol];
    if (index >= 0 && index < targetView.editors.length) {
      targetView.activeEditorIndex = index;
      notifyListeners();
    }
  }

  void reorderEditor(int oldIndex, int newIndex, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;
    final targetView = _splitViews[targetRow][targetCol];

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

  void togglePin(int index, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;
    final targetView = _splitViews[targetRow][targetCol];

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
