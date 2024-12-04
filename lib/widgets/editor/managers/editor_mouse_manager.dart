// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
import 'dart:math';

import 'package:crystal/core/editor/editor_core.dart';
import 'package:crystal/models/editor/mouse/mouse_click_type.dart';
import 'package:flutter/material.dart';

class EditorMouseManager {
  final EditorCore core;

  bool _isDragging = false;
  (int, int)? _dragStartPosition;
  (int, int)? _dragCurrentPosition;

  DateTime? _firstClickTime;
  DateTime? _secondClickTime;
  Offset? _lastClickPosition;
  int _clickCount = 0;

  EditorMouseManager(this.core);

  void handleMouseEvent(
      PointerEvent event, Offset localPosition, Offset scrollPosition) {
    if (event is PointerDownEvent) {
      _handlePointerDown(event, localPosition, scrollPosition);
    } else if (event is PointerMoveEvent) {
      _handlePointerMove(event, localPosition, scrollPosition);
    } else if (event is PointerUpEvent) {
      _handlePointerUp(event, localPosition, scrollPosition);
    }
  }

  void _handlePointerDown(
      PointerDownEvent event, Offset localPosition, Offset scrollPosition) {
    final textPosition =
        _convertPositionToTextIndex(localPosition, scrollPosition);

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

    // Start dragging
    _isDragging = true;
    _dragStartPosition = textPosition;
    _dragCurrentPosition = textPosition;
  }

  void _handlePointerMove(
      PointerMoveEvent event, Offset localPosition, Offset scrollPosition) {
    if (_isDragging) {
      final currentPosition =
          _convertPositionToTextIndex(localPosition, scrollPosition);

      // Update current dragging position
      _dragCurrentPosition = currentPosition;

      if (_dragStartPosition != null) {
        // Select from drag start to current position
        core.selectRange(_dragStartPosition!.$1, _dragStartPosition!.$2,
            currentPosition.$1, currentPosition.$2);
      }
    }
  }

  void _handlePointerUp(
      PointerUpEvent event, Offset localPosition, Offset scrollPosition) {
    _isDragging = false;
    _dragStartPosition = null;
    _dragCurrentPosition = null;
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
      _clickCount = 1;
      _lastClickPosition = localPosition;
      return MouseClickType.single;
    }

    // Second click
    if (_secondClickTime == null) {
      final timeDiff = now.difference(_firstClickTime!);
      if (timeDiff.inMilliseconds < 300) {
        _secondClickTime = now;
        _clickCount = 2;
        _lastClickPosition = localPosition;
        return MouseClickType.double;
      }

      // Reset if too slow
      _resetClickTracking();
      _firstClickTime = now;
      _clickCount = 1;
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
    _clickCount = 1;
    _lastClickPosition = localPosition;
    return MouseClickType.single;
  }

  void _resetClickTracking() {
    _firstClickTime = null;
    _secondClickTime = null;
    _clickCount = 0;
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
    core.moveCursorTo(cursorLine, cursorIndex);
    core.clearSelection();
  }

  void _handleDoubleClick(int cursorLine, int cursorIndex) {
    core.selectWord(cursorLine, cursorIndex);
  }

  void _handleTripleClick(int cursorLine, int cursorIndex) {
    core.selectLine(cursorLine, cursorIndex);
  }
}

extension EditorCoreMouseExtensions on EditorCore {
  void moveCursorTo(int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    cursorManager.moveTo(cursorLine, cursorIndex);
    notifyListeners();
  }

  void selectWord(int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    int wordEnd =
        selectionManager.selectWord(bufferManager, cursorLine, cursorIndex);
    if (wordEnd <= bufferManager.lines[cursorLine].length) {
      cursorManager.cursorIndex = wordEnd;
    }
    notifyListeners();
  }

  void selectLine(int cursorLine, int cursorIndex) {
    cursorLine = min(cursorLine, bufferManager.lines.length - 1);
    cursorIndex = min(cursorIndex, bufferManager.lines[cursorLine].length);

    selectionManager.selectLine(bufferManager, cursorLine);
    cursorManager.cursorLine++;
    cursorManager.cursorIndex = 0;
    notifyListeners();
  }

  void selectRange(int startLine, int startIndex, int endLine, int endIndex) {
    startLine = max(0, min(startLine, bufferManager.lines.length - 1));
    startIndex = min(startIndex, bufferManager.lines[startLine].length);
    endLine = max(0, min(endLine, bufferManager.lines.length - 1));
    endIndex = min(endIndex, bufferManager.lines[endLine].length);

    selectionManager.selectRange(
        bufferManager, startLine, startIndex, endLine, endIndex);
    notifyListeners();
  }
}
