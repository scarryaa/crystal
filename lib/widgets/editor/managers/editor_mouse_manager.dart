// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/cursor/cursor.dart';
import 'package:crystal/models/editor/mouse/mouse_button_type.dart';
import 'package:crystal/models/editor/mouse/mouse_click_type.dart';
import 'package:crystal/models/selection/selection_direction.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorMouseManager extends ChangeNotifier {
  final EditorCore core;

  bool _isDragging = false;
  (int, int)? _dragStartPosition;

  DateTime? _firstClickTime;
  DateTime? _secondClickTime;
  Offset? _lastClickPosition;
  Cursor? _lastClickCursor;

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
    if (_isDragging) {
      final currentPosition =
          _convertPositionToTextIndex(localPosition, scrollPosition);

      if (_dragStartPosition != null) {
        core.selectRange(_dragStartPosition!.$1, _dragStartPosition!.$2,
            currentPosition.$1, currentPosition.$2);

        if (_lastClickCursor!.line < core.bufferManager.lines.length &&
            _lastClickCursor!.line >= 0) {
          core.cursorManager.moveTo(
              core.cursorManager.cursors.indexOf(_lastClickCursor!),
              currentPosition.$1,
              currentPosition.$2);
        }

        if (_dragStartPosition!.$1 != currentPosition.$1 ||
            _dragStartPosition!.$2 != currentPosition.$2) {
          if (currentPosition.$1 < core.bufferManager.lines.length &&
              currentPosition.$1 >= 0) {
            final int currentLineLength =
                core.bufferManager.getLineAt(currentPosition.$1).length;
            if (currentPosition.$2 <= currentLineLength &&
                currentPosition.$2 >= 0) {
              _lastClickCursor =
                  Cursor(line: currentPosition.$1, index: currentPosition.$2);
            } else if (currentPosition.$2 <= 0) {
              _lastClickCursor = Cursor(line: currentPosition.$1, index: 0);
            } else {
              _lastClickCursor =
                  Cursor(line: currentPosition.$1, index: currentLineLength);
            }
          } else if (currentPosition.$1 >= 0) {
            final int lastLineLength = core.bufferManager
                .getLineAt(core.bufferManager.lines.length - 1)
                .length;
            _lastClickCursor = Cursor(
                line: core.bufferManager.lines.length - 1,
                index: lastLineLength);
          } else {
            final int firstLineLength = core.bufferManager.getLineLength(0);
            _lastClickCursor = Cursor(
                line: 0,
                index:
                    max(0, min(max(0, currentPosition.$2), firstLineLength)));
          }
        } else {
          _lastClickCursor = Cursor(
              line: _dragStartPosition!.$1, index: _dragStartPosition!.$2);
        }
        notifyListeners();
      }
    }
  }

  void _handlePointerUp(
      PointerUpEvent event, Offset localPosition, Offset scrollPosition) {
    _isDragging = false;
    _dragStartPosition = null;
    core.selectionManager.mergeOverlappingSelections(core.bufferManager);
    for (var selection in core.selectionManager.selections) {
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
          .isWithinSelection(core.bufferManager, cursorLine, cursorIndex);
      if (isWithinSelection && !selection.isNullSelection()) {
        core.selectionManager.removeSelection(selection);
        final foundCursors = core.cursorManager.findCursorsWithinBounds(
            selection.startLine,
            selection.endLine,
            selection.startIndex,
            selection.endIndex);
        if (core.cursorManager.cursors.length == 1) return;

        for (var cursor in foundCursors) {
          if (core.cursorManager.cursors.length > 1) {
            core.cursorManager.removeCursor(cursor, keepAnchor: false);
          }
        }
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
      core.clearSelection();
    }
  }

  void _handleDoubleClick(int cursorLine, int cursorIndex) {
    core.selectWord(cursorLine, cursorIndex);
  }

  void _handleTripleClick(int cursorLine, int cursorIndex) {
    core.selectLine(cursorLine, cursorIndex);
  }
}

extension EditorCoreMouseExtensions on EditorCore {
  void moveCursorTo(int index, int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    cursorManager.moveTo(index, cursorLine, cursorIndex);
    notifyListeners();
  }

  void selectWord(int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    final int wordEnd =
        selectionManager.selectWord(bufferManager, cursorLine, cursorIndex);
    if (wordEnd <= bufferManager.lines[cursorLine].length) {
      cursorManager.clearCursors();
      cursorManager.addCursor(Cursor(line: cursorLine, index: wordEnd));
    }
    notifyListeners();
  }

  void selectLine(int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    selectionManager.selectLine(bufferManager, 0, cursorLine);
    cursorManager.clearCursors();
    cursorManager.addCursor(Cursor(line: cursorLine, index: cursorIndex));

    cursorManager.firstCursor().line++;
    cursorManager.firstCursor().line =
        min(cursorManager.firstCursor().line, bufferManager.lines.length - 1);

    cursorManager.firstCursor().index = 0;
    notifyListeners();
  }

  void selectRange(int startLine, int startIndex, int endLine, int endIndex) {
    startLine = max(0, min(startLine, bufferManager.lines.length - 1));
    startIndex = min(startIndex, bufferManager.lines[startLine].length);
    endLine = max(0, min(endLine, bufferManager.lines.length - 1));
    endIndex = min(endIndex, bufferManager.lines[endLine].length);

    selectionManager.selectRange(
        bufferManager, startIndex, 0, startLine, startIndex, endLine, endIndex);
    cursorManager.targetCursorIndex = endIndex;
    notifyListeners();
  }
}
