import 'dart:io';

import 'package:crystal/models/cursor.dart';
import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/models/selection.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_cursor_manager.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/editor/editor_selection_manager.dart';
import 'package:crystal/services/editor/folding_manager.dart';
import 'package:crystal/services/file_service.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class InputHandler {
  final Buffer buffer;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final EditorCursorManager editorCursorManager;
  final EditorSelectionManager editorSelectionManager;
  final FoldingManager foldingManager;
  final Function() notifyListeners;
  final Function() undo;
  final Function() redo;
  final Function(String)? onDirectoryChanged;
  final FileService fileService;

  InputHandler({
    required this.buffer,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.editorCursorManager,
    required this.editorSelectionManager,
    required this.foldingManager,
    required this.notifyListeners,
    required this.undo,
    required this.redo,
    required this.onDirectoryChanged,
    required this.fileService,
  });

  void handleDragStart(double dy, double dx,
      Function(String line) measureLineWidth, bool isAltPressed) {
    handleTap(dy, dx, measureLineWidth, isAltPressed);
    editorSelectionManager.startSelection(editorCursorManager.cursors);
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

    editorCursorManager.clearAll();
    editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));

    if (isFolded && foldStart != null && foldEnd != null) {
      _handleFoldedSelection(bufferLine, targetColumn, foldStart, foldEnd);
    } else {
      editorSelectionManager.updateSelection(editorCursorManager.cursors);
    }

    notifyListeners();
  }

  Future<bool> handleSpecialKeys(bool isControlPressed, bool isShiftPressed,
      LogicalKeyboardKey key) async {
    switch (key) {
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
          return true;
        }
        if (isControlPressed) {
          undo();
          return true;
        }
        break;
      case LogicalKeyboardKey.keyQ:
        if (isControlPressed) {
          // TODO: check for unsaved files
          exit(0);
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
      editorCursorManager.clearAll();
      editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));
      editorSelectionManager.clearAll();
    } else {
      _handleMultiCursor(bufferLine, targetColumn);
    }
    notifyListeners();
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
    notifyListeners();
  }

  Future<bool> _handleDirectoryChange() async {
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    onDirectoryChanged!(selectedDirectory ?? fileService.rootDirectory);
    return true;
  }

  Future<bool> _handleFullScreenToggle() async {
    await windowManager.setFullScreen(!await windowManager.isFullScreen());
    return true;
  }

  void _handleMultiCursor(int bufferLine, int targetColumn) {
    if (editorCursorManager.cursorExistsAtPosition(bufferLine, targetColumn)) {
      if (editorCursorManager.cursors.length > 1) {
        editorCursorManager.removeCursor(Cursor(bufferLine, targetColumn));
      }
    } else {
      editorCursorManager.addCursor(Cursor(bufferLine, targetColumn));
    }
    editorSelectionManager.clearAll();
  }
}
