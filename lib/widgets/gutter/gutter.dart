import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/editor/editor_state.dart';

class Gutter extends StatefulWidget {
  final ScrollController verticalScrollController;
  final EditorState editorState;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final VoidCallback onFoldToggled;

  const Gutter({
    super.key,
    required this.verticalScrollController,
    required this.editorState,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.onFoldToggled,
  });

  @override
  State<Gutter> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  EditorState get editorState => widget.editorState;
  int? hoveredLine;
  double? hoverX;
  double? hoverY;

  double get gutterWidth {
    final lineCount = editorState.buffer.lineCount;
    final textPainter = TextPainter(
      text: TextSpan(
        text: lineCount.toString(),
        style: TextStyle(
          fontSize: widget.editorConfigService.config.fontSize,
          fontFamily: widget.editorConfigService.config.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    return textPainter.width + 64.0;
  }

  int getActualLineCount() {
    int visibleCount = 0;
    for (int i = 0; i < editorState.buffer.lineCount; i++) {
      if (!editorState.isLineHidden(i)) {
        visibleCount++;
      }
    }
    return visibleCount;
  }

  int getVisibleLineCount() {
    final lineHeight = widget.editorLayoutService.config.lineHeight;
    final viewportLineCount =
        (widget.editorState.scrollState.viewportHeight / lineHeight).ceil();

    // Find how many actual buffer lines we need to get viewportLineCount visible lines
    int visibleCount = 0;
    int bufferLine = 0;

    while (visibleCount < viewportLineCount &&
        bufferLine < editorState.buffer.lineCount) {
      if (!editorState.isLineHidden(bufferLine)) {
        visibleCount++;
      }
      bufferLine++;
    }

    return bufferLine;
  }

  int? _getLineFromY(double y) {
    // Calculate which visual line was clicked
    double adjustedY = y + widget.verticalScrollController.offset;
    int targetVisualLine =
        adjustedY ~/ widget.editorLayoutService.config.lineHeight;

    // Start from the first visible line and count visible lines until we reach the target
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (bufferLine < editorState.buffer.lineCount &&
        currentVisualLine <= targetVisualLine) {
      if (!editorState.isLineHidden(bufferLine)) {
        if (currentVisualLine == targetVisualLine) {
          return bufferLine;
        }
        currentVisualLine++;
      }
      bufferLine++;
    }

    // If we've gone past the end, return the last valid line
    return bufferLine > 0 ? bufferLine - 1 : 0;
  }

  void _handleGutterSelection(double localY, bool isMultiSelect) {
    final line = _getLineFromY(localY);
    if (line == null) return;

    editorState.selectLine(isMultiSelect, line);
  }

  void _handleGutterDrag(DragUpdateDetails details) {
    final line = _getLineFromY(details.localPosition.dy);
    if (line == null) return;

    editorState.selectLine(true, line);
  }

  void _handleGutterTap(TapDownDetails details) {
    final line = _getLineFromY(details.localPosition.dy);
    if (line == null) return;

    // Calculate line number text width dynamically
    final lineNumberText = (line + 1).toString();
    final textPainter = TextPainter(
      text: TextSpan(
        text: lineNumberText,
        style: TextStyle(
          fontSize: widget.editorConfigService.config.fontSize,
          fontFamily: widget.editorConfigService.config.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const iconWidth = 18.0;
    const iconPadding = 8.0;

    // Calculate click zones
    final lineNumberWidth = textPainter.width;
    final foldIconStart = gutterWidth - iconPadding - iconWidth;
    final foldIconEnd = foldIconStart + iconWidth;

    // Check if click is in fold icon zone
    if (details.localPosition.dx >= foldIconStart &&
        details.localPosition.dx <= foldIconEnd) {
      _handleFoldingIconTap(line);
    } else {
      _handleGutterSelection(details.localPosition.dy, false);
    }
  }

  void _handleHover(PointerHoverEvent event) {
    setState(() {
      hoverX = event.localPosition.dx;
      hoverY = event.localPosition.dy;
    });
  }

  void _handleHoverExit(PointerExitEvent event) {
    setState(() {
      hoverX = null;
      hoverY = null;
    });
  }

  void _handleFoldingIconTap(int line) {
    if (editorState.isFoldable(line) || editorState.isLineFolded(line)) {
      if (editorState.isLineFolded(line)) {
        // Get the existing fold end from foldingRanges
        final foldEnd = editorState.foldingRanges[line];
        if (foldEnd != null) {
          // Store nested folds before unfolding
          Map<int, int> nestedFolds = {};
          for (var entry in editorState.foldingRanges.entries) {
            if (entry.key > line && entry.key < foldEnd) {
              nestedFolds[entry.key] = entry.value;
            }
          }

          // Unfold the parent and restore nested folds
          editorState.toggleFold(line, foldEnd, nestedFolds: nestedFolds);
        }
      } else {
        // Find fold end for unfoldable line
        final endLine = _findFoldingEndLine(line);
        if (endLine != null) {
          editorState.toggleFold(line, endLine);
        }
      }

      widget.onFoldToggled();
    }
  }

  int? _findFoldingEndLine(int startLine) {
    if (startLine >= editorState.buffer.lines.length) return null;

    final baseIndent = _getIndentation(editorState.buffer.lines[startLine]);
    if (baseIndent == -1) return null;

    for (int i = startLine + 1; i < editorState.buffer.lines.length; i++) {
      final currentLine = editorState.buffer.lines[i];
      if (currentLine.trim().isEmpty) continue;

      final currentIndent = _getIndentation(currentLine);
      if (currentIndent <= baseIndent) {
        return i - 1;
      }
    }

    return editorState.buffer.lines.length - 1;
  }

  int _getIndentation(String line) {
    final match = RegExp(r'[^\s]').firstMatch(line);
    return match?.start ?? -1;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate the height needed for all content
    double contentHeight =
        getActualLineCount() * widget.editorLayoutService.config.lineHeight +
            widget.editorLayoutService.config.verticalPadding;

    // Get viewport height from the editor state
    double viewportHeight = widget.editorState.scrollState.viewportHeight;

    // Use the larger of viewport height or content height
    double height = max(viewportHeight, contentHeight);

    return Consumer<EditorState>(
      builder: (context, editorState, child) {
        return Align(
            alignment: Alignment.topLeft,
            child: MouseRegion(
                onHover: _handleHover,
                onExit: _handleHoverExit,
                child: Container(
                  width: gutterWidth,
                  height: height,
                  color: widget.editorConfigService.themeService.currentTheme
                          ?.background ??
                      Colors.white,
                  child: ScrollConfiguration(
                    behavior:
                        const ScrollBehavior().copyWith(scrollbars: false),
                    child: GestureDetector(
                      onTapDown: _handleGutterTap,
                      onPanStart: (details) => _handleGutterSelection(
                          details.localPosition.dy, false),
                      onPanUpdate: _handleGutterDrag,
                      child: SingleChildScrollView(
                        controller: widget.verticalScrollController,
                        child: SizedBox(
                          width: gutterWidth,
                          height: height,
                          child: CustomPaint(
                            painter: GutterPainter(
                              textColor: widget.editorConfigService.themeService
                                      .currentTheme?.textLight ??
                                  Colors.grey,
                              highlightColor: widget.editorConfigService
                                      .themeService.currentTheme?.primary ??
                                  Colors.blue,
                              editorConfigService: widget.editorConfigService,
                              editorLayoutService: widget.editorLayoutService,
                              editorState: editorState,
                              verticalOffset:
                                  widget.verticalScrollController.hasClients
                                      ? widget.verticalScrollController.offset
                                      : 0,
                              viewportHeight: viewportHeight,
                              hoveredLine: hoveredLine,
                              hoverX: hoverX,
                              hoverY: hoverY,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                )));
      },
    );
  }
}
