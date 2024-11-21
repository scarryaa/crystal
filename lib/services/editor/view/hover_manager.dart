import 'dart:async';

import 'package:crystal/models/editor/config/editor_view_config.dart';
import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart' as lsp_models;
import 'package:crystal/models/editor/position.dart';
import 'package:crystal/models/text_range.dart';
import 'package:crystal/models/word_info.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:flutter/services.dart' hide TextRange;

class HoverManager {
  final EditorViewConfig config;
  bool isHoveringPopup = false;
  bool isHoveringWord = false;
  WordInfo? lastHoveredWord;
  Offset? hoverPosition;
  TextRange? hoveredWordRange;
  Timer? wordHighlightTimer;
  Timer? hoverTimer;
  List<lsp_models.Diagnostic>? hoveredInfo;

  HoverManager({
    required this.config,
  });

  void handleHover(PointerHoverEvent event, Position cursorPosition) {}

  void cancelHoverOperations() {
    hoverTimer?.cancel();
    wordHighlightTimer?.cancel();

    isHoveringWord = false;
    hoveredWordRange = null;
    lastHoveredWord = null;
    hoverPosition = null;

    EditorEventBus.emit(HoverEvent(
      line: -100,
      character: -100,
      content: '',
    ));
  }

  void handleEmptyWord() {
    isHoveringWord = false;
    EditorEventBus.emit(HoverEvent(
      line: -100,
      character: -100,
      content: '',
    ));

    hoveredWordRange = null;
    lastHoveredWord = null;
  }

  WordInfo? getWordInfoAtPosition(Position position) {
    final line = config.state.buffer.getLine(position.line);
    final wordBoundaryPattern = RegExp(r'[a-zA-Z0-9_]+');
    final matches = wordBoundaryPattern.allMatches(line);

    for (final match in matches) {
      if (match.start <= position.column && position.column <= match.end) {
        return WordInfo(
          word: line.substring(match.start, match.end),
          startColumn: match.start,
          endColumn: match.end,
          startLine: position.line,
        );
      }
    }
    return null;
  }

  Position getPositionFromOffset(Offset offset) {
    final line =
        (offset.dy / config.services.layoutService.config.lineHeight).floor();
    final column =
        (offset.dx / config.services.layoutService.config.charWidth).floor();
    return Position(line: line, column: column);
  }

  void hidePopups() {
    isHoveringPopup = false;
    isHoveringWord = false;
    hoveredWordRange = null;
    EditorEventBus.emit(HoverEvent(
      line: -100,
      character: -100,
      content: '',
    ));
  }

  void dispose() {
    hoverTimer?.cancel();
  }
}
