// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:math';

import 'package:crystal/core/editor/buffer_manager.dart';
import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/editor/mouse/mouse_button_type.dart';
import 'package:crystal/models/editor/mouse/mouse_click_type.dart';
import 'package:crystal/models/editor/selection/selection.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:crystal/util/utils.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorMouseManager extends ChangeNotifier {
  final EditorCore core;

  bool _isDragging = false;
  (int, int)? _dragStartPosition;

  int _currentLayer = 0;
  DateTime? _firstClickTime;
  DateTime? _secondClickTime;
  Offset? _lastClickPosition;
  Cursor? _lastClickCursor;
  MouseClickType? _lastClickType;
  Selection? _lastSelectedWord;
  Selection? _lastSelectedLine;

  EditorMouseManager(this.core);

  void handleMouseEvent(
      PointerEvent event, Offset localPosition, Offset scrollPosition) {
    MouseButtonType mouseButton;
    switch (event.buttons) {
      case kPrimaryMouseButton:
        mouseButton = MouseButtonType.left;
        break;
      case kMiddleMouseButton:
        mouseButton = MouseButtonType.middle;
        break;
      case kSecondaryMouseButton:
        mouseButton = MouseButtonType.right;
        break;
      default:
        mouseButton = MouseButtonType.left;
    }

    if (event is PointerDownEvent) {
      _handlePointerDown(event, localPosition, scrollPosition, mouseButton);
    } else if (event is PointerMoveEvent) {
      _handlePointerMove(event, localPosition, scrollPosition);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event, localPosition, scrollPosition);
    }
    notifyListeners();
  }

  void _handlePointerDown(PointerDownEvent event, Offset localPosition,
      Offset scrollPosition, MouseButtonType mouseButton) {
    final textPosition =
        _convertPositionToTextIndex(localPosition, scrollPosition);

    switch (mouseButton) {
      case MouseButtonType.left:
        final clickType = _determineClickType(textPosition, localPosition);
        _lastClickType = clickType;

        switch (clickType) {
          case MouseClickType.single:
            _handleSingleClick(textPosition.$1, textPosition.$2);
            break;
          case MouseClickType.double:
            _handleDoubleClick(textPosition.$1, textPosition.$2);
            break;
          case MouseClickType.triple:
            _handleTripleClick(textPosition.$1, textPosition.$2);
            break;
        }

        _isDragging = true;
        final clampedLine =
            textPosition.$1.clamp(0, core.bufferManager.lineCount - 1);
        final clampedIndex = textPosition.$2
            .clamp(0, core.bufferManager.getLineLength(clampedLine));

        _dragStartPosition = (clampedLine, clampedIndex);
        break;

      case MouseButtonType.middle:
        _handleMiddleClick(textPosition.$1, textPosition.$2);
        _dragStartPosition = null;
        break;

      case MouseButtonType.right:
        _handleRightClick(textPosition.$1, textPosition.$2);
        _dragStartPosition = null;
        break;
    }

    core.onCursorMove!(textPosition.$1, textPosition.$2);
  }

  void _handleMiddleClick(int cursorLine, int cursorIndex) {}

  void _handleRightClick(int cursorLine, int cursorIndex) {
    // TODO
  }

  void _handlePointerMove(
      PointerMoveEvent event, Offset localPosition, Offset scrollPosition) {
    if (_dragStartPosition == null || _isDragging == false) return;

    final currentPosition =
        _convertPositionToTextIndex(localPosition, scrollPosition);

    final clampedLine =
        currentPosition.$1.clamp(0, core.bufferManager.lineCount - 1);
    final clampedCurrentPosition = (
      clampedLine,
      currentPosition.$2
          .clamp(0, core.bufferManager.getLineLength(clampedLine)),
    );

    switch (_lastClickType) {
      case MouseClickType.single:
        _handleSingleClickPointerMove(clampedCurrentPosition);
        break;
      case MouseClickType.double:
        _handleDoubleClickPointerMove(clampedCurrentPosition);
        break;
      case MouseClickType.triple:
        _handleTripleClickPointerMove(clampedCurrentPosition);
        break;
      default:
        break;
    }

    notifyListeners();
  }

  void _handleSingleClickPointerMove((int, int) currentPosition) {
    core.selectRange(_dragStartPosition!.$1, _dragStartPosition!.$2,
        currentPosition.$1, currentPosition.$2,
        layer: _currentLayer);

    // Adjust cursor
    if (_lastClickCursor != null) {
      final index = core.cursorManager.cursors.indexOf(_lastClickCursor!);
      core.cursorManager.moveTo(index, currentPosition.$1, currentPosition.$2);

      _lastClickCursor =
          Cursor(line: currentPosition.$1, index: currentPosition.$2);
    }
  }

  void _handleDoubleClickPointerMove((int, int) currentPosition) {
    if (_lastSelectedWord == null) return;

    if (_currentPositionIsWithinWord(currentPosition,
        _lastSelectedWord!.startIndex, _lastSelectedWord!.endIndex)) {
      core.clearSelection(layer: _currentLayer);
      core.selectionManager.selectRange(
          core.bufferManager,
          _lastSelectedWord!.startIndex,
          0,
          _lastSelectedWord!.startLine,
          _lastSelectedWord!.startIndex,
          _lastSelectedWord!.endLine,
          _lastSelectedWord!.endIndex,
          layer: _currentLayer);

      core.selectionManager.notifyListeners();
      notifyListeners();
      return;
    }

    if (_currentPositionIsWithinLine(currentPosition)) {
      if (currentPosition.$2 < _lastSelectedWord!.startIndex) {
        core.clearSelection(layer: _currentLayer);
        _dragStartPosition =
            (_lastSelectedWord!.startLine, _lastSelectedWord!.startIndex);
        final currentLineContent =
            core.bufferManager.getLineAt(currentPosition.$2);
        final currentWord = core.findCurrentWord(
            core.bufferManager, currentPosition.$1, currentPosition.$2);
        final previousWord =
            core.getPreviousWord(currentLineContent, currentPosition.$2);

        core.selectionManager.addSelection(
            Selection(
                anchor: _lastSelectedWord!.anchor,
                startLine: _lastSelectedWord!.startLine,
                endLine: _lastSelectedWord!.endLine,
                startIndex: _lastSelectedWord!.startIndex,
                endIndex: _lastSelectedWord!.endIndex),
            layer: _currentLayer);
        core.selectionManager.selectRange(
            core.bufferManager,
            _lastSelectedWord!.startIndex,
            0,
            _lastSelectedWord!.startLine,
            _lastSelectedWord!.startIndex,
            currentPosition.$1,
            currentWord.$2 == previousWord.$1
                ? previousWord.$1
                : currentPosition.$2 == currentWord.$2
                    ? currentPosition.$2
                    : currentWord.$1,
            layer: _currentLayer);
      } else {
        core.clearSelection(layer: _currentLayer);
        _dragStartPosition =
            (_lastSelectedWord!.startLine, _lastSelectedWord!.startIndex);
        final currentLineContent =
            core.bufferManager.getLineAt(currentPosition.$2);
        final currentWord = core.findCurrentWord(
            core.bufferManager, currentPosition.$1, currentPosition.$2);
        final nextWord =
            core.getNextWord(currentLineContent, currentPosition.$2);
        core.selectRange(
            _lastSelectedWord!.startLine,
            _lastSelectedWord!.startIndex,
            currentPosition.$1,
            currentWord.$2 == nextWord.$2
                ? nextWord.$2
                : currentPosition.$2 == currentWord.$1
                    ? currentPosition.$2
                    : currentWord.$2,
            layer: _currentLayer);
      }
    } else {
      if (currentPosition.$1 < _lastSelectedWord!.startLine) {
        core.clearSelection(layer: _currentLayer);

        _dragStartPosition = (
          _lastSelectedWord!.startLine,
          _lastSelectedWord!.endIndex,
        );
        final currentLineContent =
            core.bufferManager.getLineAt(currentPosition.$2);
        final currentWord = core.findCurrentWord(
            core.bufferManager, currentPosition.$1, currentPosition.$2);
        final previousWord =
            core.getPreviousWord(currentLineContent, currentPosition.$2);
        core.selectRange(
            _dragStartPosition!.$1,
            _dragStartPosition!.$2,
            currentPosition.$1,
            currentWord.$2 == previousWord.$1
                ? previousWord.$1
                : currentPosition.$2 == currentWord.$2
                    ? currentPosition.$2
                    : currentWord.$1,
            layer: _currentLayer);
        final firstLineSelection = core.selectionManager
            .getSelectionAtLineAndIndex(
                _lastSelectedWord!.startLine, _lastSelectedWord!.startIndex,
                layer: _currentLayer);
        firstLineSelection.selectRange(
            core.bufferManager,
            _lastSelectedWord!.startLine,
            0,
            _lastSelectedWord!.startLine,
            core.bufferManager.getLineAt(_lastSelectedWord!.startLine).length);
      } else {
        core.clearSelection(layer: _currentLayer);
        _dragStartPosition =
            (_lastSelectedWord!.startLine, _lastSelectedWord!.startIndex);
        final currentLineContent =
            core.bufferManager.getLineAt(currentPosition.$2);
        final currentWord = core.findCurrentWord(
            core.bufferManager, currentPosition.$1, currentPosition.$2);
        final nextWord =
            core.getNextWord(currentLineContent, currentPosition.$2);
        core.selectRange(
            _lastSelectedWord!.startLine,
            _lastSelectedWord!.startIndex,
            currentPosition.$1,
            currentWord.$2 == nextWord.$2
                ? nextWord.$2
                : currentPosition.$2 == currentWord.$1
                    ? currentPosition.$2
                    : currentWord.$2,
            layer: _currentLayer);
      }
    }
  }

  void _handleTripleClickPointerMove((int, int) currentPosition) {
    if (_lastSelectedLine != null &&
        currentPosition.$2 >= 0 &&
        currentPosition.$2 <=
            core.bufferManager.getLineLength(_lastSelectedLine!.startLine) &&
        currentPosition.$1 >= _lastSelectedLine!.startLine &&
        currentPosition.$1 <= _lastSelectedLine!.endLine) {
      core.selectLine(_lastSelectedLine!.endLine, _lastSelectedLine!.endIndex,
          clearSelections: true, layer: _currentLayer);
      core.cursorManager.clearCursors(keepAnchor: false);
      core.cursorManager
          .addCursor(Cursor(line: _lastSelectedLine!.endLine + 1, index: 0));
      _lastClickCursor = Cursor(line: _lastSelectedLine!.endLine + 1, index: 0);
      return;
    }

    if (currentPosition.$1 < _lastSelectedLine!.startLine) {
      core.clearSelection(layer: _currentLayer);
      core.selectLine(
          _lastSelectedLine!.startLine, _lastSelectedLine!.startIndex,
          clearSelections: true, layer: _currentLayer);
      core.cursorManager.addCursor(Cursor(
          line: _lastSelectedLine!.endLine,
          index: _lastSelectedLine!.endIndex));

      _dragStartPosition = (
        _lastSelectedLine!.startLine - 1,
        core.bufferManager.getLineLength(_lastSelectedLine!.startLine - 1)
      );
    } else if (currentPosition.$1 >= _lastSelectedLine!.endLine) {
      core.clearSelection(layer: _currentLayer);
      core.selectLine(
          _lastSelectedLine!.startLine, _lastSelectedLine!.startIndex,
          clearSelections: true, layer: _currentLayer);
      core.cursorManager.addCursor(Cursor(
          line: _lastSelectedLine!.endLine,
          index: _lastSelectedLine!.endIndex));

      _dragStartPosition = (_lastSelectedLine!.endLine + 1, 0);
    }

    core.selectRange(
        _dragStartPosition!.$1,
        _dragStartPosition!.$2,
        currentPosition.$1 >= _dragStartPosition!.$1
            ? currentPosition.$1 + 1
            : currentPosition.$1,
        0,
        layer: _currentLayer);
  }

  bool _currentPositionIsWithinDocument((int, int) currentPosition) {
    return _lastClickCursor!.line < core.bufferManager.lineCount &&
        _lastClickCursor!.line >= 0;
  }

  bool _currentPositionIsWithinWord(
      (int, int) currentPosition, int wordStartIndex, int wordEndIndex) {
    return currentPosition.$2 >= wordStartIndex &&
        currentPosition.$2 <= wordEndIndex &&
        currentPosition.$1 >= _lastSelectedWord!.startLine &&
        currentPosition.$1 <= _lastSelectedWord!.endLine;
  }

  bool _currentPositionIsWithinLine((int, int) currentPosition) {
    return (currentPosition.$1 >= _lastSelectedWord!.startLine &&
        currentPosition.$1 <= _lastSelectedWord!.endLine);
  }

  void _handlePointerUp(
      PointerUpEvent event, Offset localPosition, Offset scrollPosition) {
    _isDragging = false;
    _dragStartPosition = null;

    core.selectionManager.mergeAllLayersToFirst(core.bufferManager);
    _currentLayer = 0;

    core.selectionManager.mergeOverlappingSelections(core.bufferManager);
    for (var selection in core.selectionManager.layers[0]) {
      final overlappingCursors = core.cursorManager.findCursorsWithinBounds(
          selection.startLine,
          selection.endLine,
          selection.startIndex,
          selection.endIndex);
      if (selection.originalDirection == SelectionDirection.forward) {
        for (var cursor in overlappingCursors) {
          core.cursorManager.removeCursor(cursor, keepAnchor: false);
        }
        core.cursorManager.addCursor(
            Cursor(line: selection.endLine, index: selection.endIndex));
      } else if (selection.originalDirection == SelectionDirection.backward) {
        for (var cursor in overlappingCursors) {
          core.cursorManager.removeCursor(cursor, keepAnchor: false);
        }
        core.cursorManager.addCursor(
            Cursor(line: selection.startLine, index: selection.startIndex));
      }
    }
  }

  MouseClickType _determineClickType(
      (int, int) textPosition, Offset localPosition) {
    final now = DateTime.now();

    // Reset click count if click is far from previous click
    if (_lastClickPosition != null) {
      final distance = (localPosition - _lastClickPosition!).distance;
      if (distance > 10) {
        _resetClickTracking();
      }
    }

    // First click
    if (_firstClickTime == null) {
      _firstClickTime = now;
      _lastClickPosition = localPosition;
      final clampedLine =
          textPosition.$1.clamp(0, core.bufferManager.lineCount - 1);
      final clampedIndex = textPosition.$2
          .clamp(0, core.bufferManager.getLineLength(clampedLine));
      _lastClickCursor = Cursor(line: clampedLine, index: clampedIndex);
      return MouseClickType.single;
    }

    // Second click
    if (_secondClickTime == null) {
      final timeDiff = now.difference(_firstClickTime!);
      if (timeDiff.inMilliseconds < 300) {
        _secondClickTime = now;
        _lastClickPosition = localPosition;
        return MouseClickType.double;
      }

      // Reset if too slow
      _resetClickTracking();
      _firstClickTime = now;
      _lastClickPosition = localPosition;
      return MouseClickType.single;
    }

    // Third click
    final firstToSecondDiff = _secondClickTime!.difference(_firstClickTime!);
    final secondToThirdDiff = now.difference(_secondClickTime!);

    if (firstToSecondDiff.inMilliseconds < 300 &&
        secondToThirdDiff.inMilliseconds < 300) {
      _resetClickTracking();
      return MouseClickType.triple;
    }

    // Reset if conditions not met
    _resetClickTracking();
    _firstClickTime = now;
    _lastClickPosition = localPosition;
    return MouseClickType.single;
  }

  void _resetClickTracking() {
    _firstClickTime = null;
    _secondClickTime = null;
    _lastClickPosition = null;
  }

  (int, int) _convertPositionToTextIndex(
      Offset localPosition, Offset scrollPosition) {
    return (
      (localPosition.dy + scrollPosition.dy) ~/ core.config.lineHeight,
      (localPosition.dx + scrollPosition.dx) ~/ core.config.characterWidth
    );
  }

  void _handleSingleClick(int cursorLine, int cursorIndex) {
    final isAltPressed = HardwareKeyboard.instance.isAltPressed;

    // Ensure cursorLine is within bounds
    cursorLine = min(cursorLine, core.bufferManager.lines.length - 1);
    cursorLine = max(0, cursorLine);

    // Ensure cursorIndex is within bounds for the current line
    final lineLength = core.bufferManager.lines[cursorLine].length;
    cursorIndex = min(cursorIndex, lineLength);
    cursorIndex = max(0, cursorIndex);

    if (isAltPressed) {
      // Check if we are in an existing selection -- clear it if so
      final (isWithinSelection, selection) = core.selectionManager
          .isWithinSelection(core.bufferManager, cursorLine, cursorIndex,
              layer: _currentLayer);
      if (isWithinSelection && !selection.isNullSelection()) {
        core.selectionManager.removeSelection(selection);
        final foundCursors = core.cursorManager.findCursorsWithinBounds(
            selection.startLine,
            selection.endLine,
            selection.startIndex,
            selection.endIndex);

        for (var cursor in foundCursors) {
          core.cursorManager.removeCursor(cursor, keepAnchor: false);
        }
        core.cursorManager
            .addCursor(Cursor(line: cursorLine, index: cursorIndex));

        return;
      }

      // Check for existing cursor at clicked position
      final existingCursorIndex = core.cursorManager.cursors.indexWhere(
          (cursor) => cursor.line == cursorLine && cursor.index == cursorIndex);

      if (existingCursorIndex != -1 && core.cursorManager.cursors.length > 1) {
        // Remove existing cursor if it's not the last one
        core.cursorManager.removeCursorAt(existingCursorIndex);
      } else {
        // Add new cursor
        final newCursor = Cursor(line: cursorLine, index: cursorIndex);
        core.cursorManager.addCursor(newCursor);
      }
    } else {
      // Single cursor mode
      core.cursorManager.clearCursors();
      core.moveCursorTo(0, cursorLine, cursorIndex);
      core.clearSelection(layer: _currentLayer);
    }
  }

  void _handleDoubleClick(int cursorLine, int cursorIndex) {
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;
    if (isAltPressed) {
      _currentLayer = core.selectionManager.layers.length;
      core.selectionManager.layers.add([]);
    }

    final (wordStartIndex, wordEndIndex) =
        core.findCurrentWord(core.bufferManager, cursorLine, cursorIndex);
    core.selectRange(cursorLine, wordStartIndex, cursorLine, wordEndIndex,
        layer: _currentLayer);
    final (isWithin, selection) = core.selectionManager.isWithinSelection(
        core.bufferManager, cursorLine, cursorIndex,
        layer: _currentLayer);
    _lastSelectedWord = Selection(
        startLine: selection.startLine,
        startIndex: selection.startIndex,
        endLine: selection.endLine,
        endIndex: selection.endIndex);
  }

  void _handleTripleClick(int cursorLine, int cursorIndex) {
    final bool isAltPressed = HardwareKeyboard.instance.isAltPressed;
    if (isAltPressed) {
      _currentLayer = core.selectionManager.layers.length;
      core.selectionManager.layers.add([]);
    }

    core.clearSelection(layer: _currentLayer);
    core.selectLine(cursorLine, cursorIndex, layer: _currentLayer);
    core.moveCursorTo(0, cursorLine + 1, 0);
    _lastSelectedLine = core.selectionManager
        .isWithinSelection(core.bufferManager, cursorLine, cursorIndex,
            layer: _currentLayer)
        .$2;
  }
}

extension EditorCoreMouseExtensions on EditorCore {
  void moveCursorTo(int index, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    cursorManager.moveTo(index, cursorLine, cursorIndex);
    notifyListeners();
  }

  void selectWord(int cursorLine, int cursorIndex,
      {bool clearSelections = false, required int layer}) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    selectionManager.selectWord(bufferManager, cursorLine, cursorIndex,
        clearSelections: clearSelections, layer: layer);
    notifyListeners();
  }

  (int, int) findPreviousWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lineCount - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    while (start > 0) {
      start--;
      if (!Utils().isWordCharacter(lineContent[start])) {
        start++;
        break;
      }
    }

    if (start == 0) {
      return (start, cursorIndex);
    }

    end = start;
    while (end > 0) {
      if (!Utils().isWordCharacter(lineContent[end - 1])) {
        break;
      }
      end--;
    }

    return (start, end);
  }

  (int, int) findNextWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lineCount - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    while (start < lineContent.length) {
      start++;
      if (!Utils().isWordCharacter(lineContent[start])) {
        start--;
        break;
      }
    }

    if (start == lineContent.length) {
      return (lineContent.length, cursorIndex);
    }

    end = start;
    while (end < lineContent.length) {
      if (!Utils().isWordCharacter(lineContent[end - 1])) {
        break;
      }
      end++;
    }

    return (start, end);
  }

  (int, int) findCurrentWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lineCount - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    // find the start by going backwards until non-word character or start of line
    if (start > 0 && Utils().isWordCharacter(lineContent[start - 1])) {
      while (start > 0 && Utils().isWordCharacter(lineContent[start - 1])) {
        start--;
      }
    }

    // find the end by going forward until non-word character or end of line
    if (end < lineContent.length && Utils().isWordCharacter(lineContent[end])) {
      while (end < lineContent.length &&
          Utils().isWordCharacter(lineContent[end])) {
        end++;
      }
    }

    return (start, end);
  }

  (int, int) findCurrentNonWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lineCount - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    // Find the start by going backwards until a word character or start of line
    if (start > 0 && !Utils().isWordCharacter(lineContent[start - 1])) {
      while (start > 0 && !Utils().isWordCharacter(lineContent[start - 1])) {
        start--;
      }
    }

    // Find the end by going forward until a word character or end of line
    if (end < lineContent.length &&
        !Utils().isWordCharacter(lineContent[end])) {
      while (end < lineContent.length &&
          !Utils().isWordCharacter(lineContent[end])) {
        end++;
      }
    }

    return (start, end);
  }

  (int, int) findPreviousNonWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lineCount - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    // Handle empty line case
    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    // Start looking from the cursor index for non-word
    while (start > 0) {
      if (!Utils().isWordCharacter(lineContent[start])) {
        end = start + 1;
        while (end > 0 && !(Utils().isWordCharacter(lineContent[end]))) {
          end--;
        }
        return (start, end);
      }
      start--;
    }
    return (lineContent.length, lineContent.length);
  }

  (int, int) findNextNonWord(
      BufferManager bufferManager, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    final lineContent = bufferManager.getLineAt(cursorLine);

    // Handle empty line case
    if (lineContent.isEmpty) {
      return (0, 0);
    }

    cursorIndex = min(cursorIndex, lineContent.length);

    int start = cursorIndex;
    int end = cursorIndex;

    // Start looking from the cursor index for non-word
    while (start < lineContent.length) {
      if (!Utils().isWordCharacter(lineContent[start])) {
        end = start + 1;
        while (end < lineContent.length &&
            !(Utils().isWordCharacter(lineContent[end]))) {
          end++;
        }
        return (start, end);
      }
      start++;
    }
    return (lineContent.length, lineContent.length);
  }

  void selectLine(int cursorLine, int cursorIndex,
      {bool clearSelections = false, required int layer}) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    selectionManager.selectLine(bufferManager, 0, cursorLine,
        clearSelections: clearSelections, layer: layer);
    notifyListeners();
  }

  void selectRange(int startLine, int startIndex, int endLine, int endIndex,
      {required int layer}) {
    startLine = max(0, min(startLine, bufferManager.lines.length - 1));
    startIndex = min(startIndex, bufferManager.lines[startLine].length);
    endLine = max(0, min(endLine, bufferManager.lines.length - 1));
    endIndex = min(endIndex, bufferManager.lines[endLine].length);

    selectionManager.selectRange(
        bufferManager, startIndex, 0, startLine, startIndex, endLine, endIndex,
        layer: layer);
    cursorManager.targetCursorIndex = endIndex;
    notifyListeners();
  }
}
