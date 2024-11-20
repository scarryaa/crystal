import 'dart:io';

import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/dialog_service.dart';
import 'package:crystal/services/editor/controllers/cursor_controller.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/editor/selection_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class InputHandler {
  final Buffer buffer;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final CursorController cursorController;
  final SelectionManager editorSelectionManager;
  final FoldingManager foldingManager;
  final Function() notifyListeners;
  final Function() undo;
  final Function() redo;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;
  final String path;
  List<EditorState> editors;
  VoidCallback splitVertically;
  VoidCallback splitHorizontally;

  InputHandler({
    required this.buffer,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.cursorController,
    required this.editorSelectionManager,
    required this.foldingManager,
    required this.notifyListeners,
    required this.undo,
    required this.redo,
    required this.onDirectoryChanged,
    required this.fileService,
    required this.path,
    required this.editors,
    required this.splitHorizontally,
    required this.splitVertically,
  });

  void handleDragStart(double dy, double dx,
      Function(String line) measureLineWidth, bool isAltPressed) {
    handleTap(dy, dx, measureLineWidth, isAltPressed);
    editorSelectionManager.startSelection(cursorController.cursors);
    EditorEventBus.emit(SelectionEvent(
        selections: editorSelectionManager.selections,
        hasSelection: editorSelectionManager.hasSelection(),
        selectedText: editorSelectionManager.getSelectedText(buffer)));

    notifyListeners();
  }

  void handleDragUpdate(
      double dy, double dx, Function(String) measureLineWidth) {
    int maxVisualLine = buffer.lineCount - 1;
    int visualLine =
        (dy ~/ editorLayoutService.config.lineHeight).clamp(0, maxVisualLine);
    int bufferLine = _getBufferLineFromVisualLine(visualLine);
    bufferLine = bufferLine.clamp(0, buffer.lineCount - 1);

    bool isFolded = false;
    int? foldStart;
    int? foldEnd;
    for (final entry in buffer.foldedRanges.entries) {
      if (bufferLine >= entry.key && bufferLine <= entry.value) {
        isFolded = true;
        foldStart = entry.key;
        foldEnd = entry.value;
        break;
      }
    }

    String lineText = buffer.getLine(bufferLine);
    int targetColumn = _getColumnAtX(dx, lineText, measureLineWidth);
    cursorController.clearAll();
    cursorController.addCursor(bufferLine, targetColumn);

    if (isFolded && foldStart != null && foldEnd != null) {
      _handleFoldedSelection(bufferLine, targetColumn, foldStart, foldEnd);
    } else {
      editorSelectionManager.updateSelection(cursorController.cursors);
    }

    EditorEventBus.emit(CursorEvent(
        cursors: cursorController.cursors,
        line: bufferLine,
        column: targetColumn,
        hasSelection: editorSelectionManager.hasSelection(),
        selections: editorSelectionManager.selections));

    EditorEventBus.emit(SelectionEvent(
        selections: editorSelectionManager.selections,
        hasSelection: editorSelectionManager.hasSelection(),
        selectedText: editorSelectionManager.getSelectedText(buffer)));

    notifyListeners();
  }

  Future<bool> handleSpecialKeys(bool isControlPressed, bool isShiftPressed,
      LogicalKeyboardKey key) async {
    switch (key) {
      case LogicalKeyboardKey.insert:
        cursorController.toggleInsertMode();
        EditorEventBus.emit(
            InsertModeEvent(isInsertMode: cursorController.insertMode));
        return Future.value(true);

      case LogicalKeyboardKey.backslash:
        if (isControlPressed) {
          splitVertically();
          EditorEventBus.emit(LayoutEvent(
            type: LayoutChange.verticalSplit,
            data: {},
          ));

          return true;
        }
        break;

      case LogicalKeyboardKey.bar:
        if (isControlPressed) {
          splitHorizontally();
          EditorEventBus.emit(LayoutEvent(
            type: LayoutChange.horizontalSplit,
            data: {},
          ));
        }

      case LogicalKeyboardKey.add:
        if (isControlPressed) {
          return _handleFontSizeIncrease();
        }
        break;

      case LogicalKeyboardKey.minus:
        if (isControlPressed) {
          return _handleFontSizeDecrease();
        }
        break;

      case LogicalKeyboardKey.keyZ:
        if (isControlPressed && isShiftPressed) {
          redo();
          EditorEventBus.emit(
              TextEvent(content: buffer.content, isDirty: buffer.isDirty));
          return true;
        }
        if (isControlPressed) {
          undo();
          EditorEventBus.emit(
              TextEvent(content: buffer.content, isDirty: buffer.isDirty));
          return true;
        }
        break;

      case LogicalKeyboardKey.keyQ:
        if (isControlPressed) {
          final success = await _handleMultipleTabsSave(editors);
          if (success) {
            EditorEventBus.emit(EditorClosingEvent(saveStatus: success));
            exit(0);
          }
        }
        break;

      case LogicalKeyboardKey.keyO:
        if (isControlPressed) {
          return _handleDirectoryChange();
        }
        break;

      case LogicalKeyboardKey.keyF:
        if (isControlPressed) {
          return _handleFullScreenToggle();
        }
        break;
    }
    return false;
  }

  void handleTap(double dy, double dx, Function(String) measureLineWidth,
      bool isAltPressed) {
    int visualLine = dy ~/ editorLayoutService.config.lineHeight;
    int bufferLine = _getBufferLineFromVisualLine(visualLine);
    String lineText = buffer.getLine(bufferLine);
    int targetColumn = _getColumnAtX(dx, lineText, measureLineWidth);

    if (!isAltPressed) {
      cursorController.clearAll();
      cursorController.addCursor(bufferLine, targetColumn);
      editorSelectionManager.clearAll();
    } else {
      _handleMultiCursor(bufferLine, targetColumn);
    }

    EditorEventBus.emit(CursorEvent(
        cursors: cursorController.cursors,
        line: bufferLine,
        column: targetColumn,
        hasSelection: editorSelectionManager.hasSelection(),
        selections: editorSelectionManager.selections));

    notifyListeners();
  }

  Future<bool> _handleMultipleTabsSave(List<EditorState> editors) async {
    // Filter to only get dirty editors
    final dirtyEditors = editors.where((e) => e.buffer.isDirty).toList();

    if (dirtyEditors.isEmpty) {
      return true;
    }

    // Show prompt with multiple files message
    final response = await DialogService().showMultipleFilesPrompt(
        message:
            'You have ${dirtyEditors.length} unsaved files. What would you like to do?',
        options: ['Save All', 'Save None', 'Cancel']);

    switch (response) {
      case 'Save All':
        try {
          // Attempt to save all dirty editors
          for (final editor in dirtyEditors) {
            await editor.save();
          }
          return true;
        } catch (e) {
          // Handle save error
          return false;
        }

      case 'Save None':
        // Proceed without saving any files
        return true;

      case 'Cancel':
      default:
        // User cancelled or unknown response
        return false;
    }
  }

  // Private helper methods
  int _getBufferLineFromVisualLine(int visualLine) {
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (
        currentVisualLine < visualLine && bufferLine < buffer.lineCount - 1) {
      if (!foldingManager.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    while (bufferLine < buffer.lineCount &&
        foldingManager.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return bufferLine;
  }

  int _getColumnAtX(
      double x, String lineText, Function(String) measureLineWidth) {
    double currentWidth = 0;
    int targetColumn = 0;

    for (int i = 0; i < lineText.length; i++) {
      double charWidth = editorLayoutService.config.charWidth;
      if (currentWidth + (charWidth / 2) > x) break;
      currentWidth += charWidth;
      targetColumn = i + 1;
    }

    return targetColumn;
  }

  void _handleFoldedSelection(
      int bufferLine, int targetColumn, int foldStart, int foldEnd) {
    Selection? currentSelection = editorSelectionManager.selections.isNotEmpty
        ? editorSelectionManager.selections.first
        : null;

    if (currentSelection != null) {
      bool isSelectingBackwards = currentSelection.anchorLine > bufferLine ||
          (currentSelection.anchorLine == bufferLine &&
              targetColumn < currentSelection.anchorColumn);

      if (bufferLine <= foldStart && isSelectingBackwards) {
        editorSelectionManager.updateSelectionToLine(
            buffer, foldStart, targetColumn);
      } else if (bufferLine >= foldStart && bufferLine <= foldEnd) {
        editorSelectionManager.updateSelectionToLine(
            buffer, bufferLine, targetColumn);
      } else {
        editorSelectionManager.updateSelectionToLine(
            buffer, foldEnd, buffer.getLineLength(foldEnd));
      }
    }
  }

  bool _handleFontSizeIncrease() {
    editorConfigService.config.fontSize += 2.0;
    _updateFontSize();
    return true;
  }

  bool _handleFontSizeDecrease() {
    if (editorConfigService.config.fontSize > 8.0) {
      editorConfigService.config.fontSize -= 2.0;
      _updateFontSize();
    }
    return true;
  }

  void _updateFontSize() {
    editorLayoutService.updateFontSize(editorConfigService.config.fontSize,
        editorConfigService.config.fontFamily);
    editorLayoutService.config.lineHeight =
        editorConfigService.config.fontSize *
            editorLayoutService.config.lineHeightMultiplier;
    editorConfigService.saveConfig();

    EditorEventBus.emit(FontChangeEvent(
      fontSize: editorConfigService.config.fontSize,
      fontFamily: editorConfigService.config.fontFamily,
      lineHeight: editorLayoutService.config.lineHeight,
    ));

    notifyListeners();
  }

  Future<bool> _handleDirectoryChange() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    final directory = selectedDirectory ?? fileService.rootDirectory;
    onDirectoryChanged!(directory);

    EditorEventBus.emit(DirectoryChangeEvent(path: directory));

    return true;
  }

  Future<bool> _handleFullScreenToggle() async {
    final isFullScreen = !await windowManager.isFullScreen();
    await windowManager.setFullScreen(isFullScreen);

    EditorEventBus.emit(FullscreenChangeEvent(isFullScreen: isFullScreen));

    return true;
  }

  void _handleMultiCursor(int bufferLine, int targetColumn) {
    if (cursorController.cursorExistsAtPosition(bufferLine, targetColumn)) {
      if (cursorController.cursors.length > 1) {
        cursorController.removeCursor(bufferLine, targetColumn);
      }
    } else {
      cursorController.addCursor(bufferLine, targetColumn);
    }
    editorSelectionManager.clearAll();
  }
}
