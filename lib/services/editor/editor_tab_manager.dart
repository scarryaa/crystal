import 'package:crystal/models/editor/split_view.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class EditorTabManager extends ChangeNotifier {
  final Function(int, int)? onSplitViewClosed;
  final FileService fileService;
  final Function(String)? onDirectoryChanged;
  final GitService gitService;

  EditorTabManager({
    this.onSplitViewClosed,
    required this.fileService,
    required this.onDirectoryChanged,
    required this.gitService,
  });

  final List<List<SplitView>> _splitViews = [
    [SplitView()]
  ];
  int activeRow = 0;
  int activeCol = 0;
  final List<List<double>> _horizontalSizes = [
    [1.0]
  ];
  final List<double> _verticalSizes = [1.0];

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

    // Update sizes
    final newSize = 1.0 / _splitViews.length;
    _verticalSizes.clear();
    for (var i = 0; i < _splitViews.length; i++) {
      _verticalSizes.add(newSize);
    }

    activeRow = _splitViews.length - 1;
    activeCol = 0;

    notifyListeners();
  }

  void addVerticalSplit() {
    if (activeEditor == null) return;

    // First ensure _horizontalSizes has an entry for the active row
    while (_horizontalSizes.length <= activeRow) {
      _horizontalSizes.add([1.0]);
    }

    final newSplitView = SplitView();
    final newEditor = _copyEditorState(activeEditor!);
    newSplitView.editors.add(newEditor);
    newSplitView.activeEditorIndex = 0;
    _splitViews[activeRow].add(newSplitView);

    // Update sizes
    final newSize = 1.0 / _splitViews[activeRow].length;
    _horizontalSizes[activeRow] =
        List.generate(_splitViews[activeRow].length, (_) => newSize);

    activeCol = _splitViews[activeRow].length - 1;
    notifyListeners();
  }

  void updateHorizontalSizes(int row, List<double> sizes) {
    if (row < _horizontalSizes.length) {
      _horizontalSizes[row] = sizes;
      notifyListeners();
    }
  }

  void updateVerticalSizes(List<double> sizes) {
    _verticalSizes.clear();
    _verticalSizes.addAll(sizes);
    notifyListeners();
  }

  List<double> getHorizontalSizes(int row) {
    if (row >= horizontalSplits.length || horizontalSplits[row].isEmpty) {
      return [];
    }
    return List.filled(
        horizontalSplits[row].length, 1.0 / horizontalSplits[row].length);
  }

  List<double> getVerticalSizes() {
    if (_verticalSizes.isEmpty || horizontalSplits.isEmpty) {
      return List.filled(
          horizontalSplits.length, 1.0 / horizontalSplits.length);
    }
    return List.from(_verticalSizes);
  }

  void closeEditor(int index, {int? row, int? col}) {
    final targetRow = row ?? activeRow;
    final targetCol = col ?? activeCol;
    final targetView = _splitViews[targetRow][targetCol];

    // Early return conditions
    if (targetView.editors.isEmpty ||
        targetView.editors[index].isPinned ||
        index >= targetView.editors.length) {
      return;
    }

    targetView.editors.removeAt(index);

    // Adjust active editor index
    if (targetView.editors.isEmpty) {
      // If this is the last split view, don't close it
      if (_splitViews.length == 1 && _splitViews[0].length == 1) {
        targetView.activeEditorIndex = -1;
      } else {
        // Let closeSplitView handle the cleanup
        closeSplitView(targetRow, targetCol);
        return;
      }
    } else {
      // Adjust active editor index for remaining editors
      if (targetView.activeEditorIndex >= targetView.editors.length) {
        targetView.activeEditorIndex = targetView.editors.length - 1;
      } else if (targetView.activeEditorIndex == index) {
        targetView.activeEditorIndex =
            index.clamp(0, targetView.editors.length - 1);
      }
    }

    notifyListeners();
  }

  void closeSplitView(int row, int col) {
    // Don't close if it's the last split view
    if (_splitViews.length == 1 && _splitViews[0].length == 1) {
      return;
    }

    // Validate indices
    if (row >= _splitViews.length || col >= _splitViews[row].length) {
      return;
    }

    onSplitViewClosed?.call(row, col);

    _splitViews[row].removeAt(col);

    // Remove empty row if needed
    if (_splitViews[row].isEmpty) {
      if (_splitViews.length > 1) {
        _splitViews.removeAt(row);
      } else {
        // Keep at least one split view
        _splitViews[row].add(SplitView());
      }
    }

    // Adjust active indices
    activeRow = activeRow.clamp(0, _splitViews.length - 1);
    activeCol = activeCol.clamp(0, _splitViews[activeRow].length - 1);

    notifyListeners();
  }

  void closeTabsToRight(int index, {required int row, required int col}) {
    if (index < horizontalSplits[row][col].editors.length - 1) {
      horizontalSplits[row][col]
          .editors
          .removeRange(index + 1, horizontalSplits[row][col].editors.length);
      _updateActiveEditor(row, col);
      notifyListeners();
    }
  }

  void closeTabsToLeft(int index, {required int row, required int col}) {
    if (index > 0) {
      horizontalSplits[row][col].editors.removeRange(0, index);
      horizontalSplits[row][col].activeEditorIndex = 0;
      _updateActiveEditor(row, col);
      notifyListeners();
    }
  }

  void closeOtherTabs(int index, {required int row, required int col}) {
    final keepEditor = horizontalSplits[row][col].editors[index];
    horizontalSplits[row][col].editors.clear();
    horizontalSplits[row][col].editors.add(keepEditor);
    horizontalSplits[row][col].activeEditorIndex = 0;
    _updateActiveEditor(row, col);
    notifyListeners();
  }

  void _updateActiveEditor(int row, int col) {
    if (horizontalSplits[row][col].activeEditorIndex >=
        horizontalSplits[row][col].editors.length) {
      horizontalSplits[row][col].activeEditorIndex =
          horizontalSplits[row][col].editors.length - 1;
    }
  }

  EditorState _copyEditorState(EditorState source) {
    final newEditor = EditorState(
      editorConfigService: source.editorConfigService,
      editorLayoutService: source.editorLayoutService,
      path: source.path,
      relativePath: source.relativePath,
      tapCallback: source.tapCallback,
      resetGutterScroll: source.resetGutterScroll,
      fileService: fileService,
      onDirectoryChanged: onDirectoryChanged,
      editors: editors,
      editorTabManager: this,
      gitService: gitService,
    );

    newEditor.openFile(source.buffer.content);
    newEditor.setAllCursors(List.from(source.cursors));
    newEditor.setAllSelections(List.from(source.selections));

    return newEditor;
  }

  EditorState? findEditorWithFile(String filePath) {
    for (var row in horizontalSplits) {
      for (var col in row) {
        for (var editor in col.editors) {
          if (editor.path == filePath) {
            return editor;
          }
        }
      }
    }
    return null;
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
