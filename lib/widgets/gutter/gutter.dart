import 'dart:math';

import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/widgets/gutter/gutter_painter.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/editor/editor_state.dart';

class Gutter extends StatefulWidget {
  final ScrollController verticalScrollController;
  final EditorState editorState;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  const Gutter({
    super.key,
    required this.verticalScrollController,
    required this.editorState,
    required this.editorLayoutService,
    required this.editorConfigService,
  });

  @override
  State<Gutter> createState() => _GutterState();
}

class _GutterState extends State<Gutter> {
  EditorState get editorState => widget.editorState;

  double get gutterWidth {
    // Use total line count for gutter width calculation
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

    return textPainter.width + 32.0;
  }

  int getVisibleLineCount() {
    int visibleCount = 0;
    for (int i = 0; i < editorState.buffer.lineCount; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        visibleCount++;
      }
    }
    return visibleCount;
  }

  int? _getLineFromY(double y) {
    double adjustedY = y + widget.verticalScrollController.offset;
    // Convert from visual position to buffer position
    int visualLine = adjustedY ~/ widget.editorLayoutService.config.lineHeight;
    return getBufferLine(visualLine);
  }

  void _handleGutterSelection(double localY, bool isMultiSelect) {
    double adjustedY = localY + widget.verticalScrollController.offset;
    int visualLine = adjustedY ~/ widget.editorLayoutService.config.lineHeight;

    // Convert visual line to buffer line accounting for folded regions
    int bufferLine = getBufferLine(visualLine);

    if (bufferLine >= editorState.buffer.lineCount) {
      editorState.selectLine(isMultiSelect, editorState.buffer.lineCount - 1);
    } else {
      editorState.selectLine(isMultiSelect, bufferLine);
    }
  }

  int getBufferLine(int visualLine) {
    int currentVisualLine = 0;
    int bufferLine = 0;

    // Iterate through buffer lines until we reach the target visual line
    while (currentVisualLine < visualLine &&
        bufferLine < editorState.buffer.lineCount) {
      if (!editorState.foldingState.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    // Ensure we don't return a hidden line
    while (bufferLine < editorState.buffer.lineCount &&
        editorState.foldingState.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return min(bufferLine, editorState.buffer.lineCount - 1);
  }

  void _handleGutterDrag(DragUpdateDetails details) {
    double adjustedY =
        details.localPosition.dy + widget.verticalScrollController.offset;
    int visualLine = adjustedY ~/ widget.editorLayoutService.config.lineHeight;
    int bufferLine = getBufferLine(visualLine);

    editorState.selectLine(true, bufferLine);
  }

  void _handleGutterTap(TapDownDetails details) {
    final line = _getLineFromY(details.localPosition.dy);
    if (line == null) return;

    // Check if tap is in folding indicator area
    if (details.localPosition.dx < 20) {
      _handleFoldingIconTap(line);
    } else {
      _handleGutterSelection(details.localPosition.dy, false);
    }
  }

  bool _isFoldable(int line) {
    if (line >= editorState.buffer.lines.length) return false;

    final currentLine = editorState.buffer.lines[line];
    final currentIndent = _getIndentation(currentLine);

    if (line + 1 < editorState.buffer.lines.length) {
      final nextLine = editorState.buffer.lines[line + 1];
      final nextIndent = _getIndentation(nextLine);
      return nextIndent > currentIndent;
    }
    return false;
  }

  int _getIndentation(String line) {
    return line.indexOf(RegExp(r'[^\s]'));
  }

  void _handleFoldingIconTap(int line) {
    if (_isFoldable(line)) {
      final endLine = _findFoldingEndLine(line);
      if (endLine != null) {
        editorState.foldingState.toggleFold(line, endLine);
      }
    }
  }

  int? _findFoldingEndLine(int startLine) {
    final startIndent = _getIndentation(editorState.buffer.lines[startLine]);

    for (int i = startLine + 1; i < editorState.buffer.lineCount; i++) {
      final currentIndent = _getIndentation(editorState.buffer.lines[i]);
      if (currentIndent <= startIndent &&
          editorState.buffer.lines[i].trim().isNotEmpty) {
        return i - 1;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Calculate height based on visible content and viewport
    double contentHeight =
        getVisibleLineCount() * widget.editorLayoutService.config.lineHeight +
            widget.editorLayoutService.config.verticalPadding;

    double height = max(
        contentHeight,
        // Only use viewport height if content doesn't fill it
        contentHeight < MediaQuery.of(context).size.height
            ? MediaQuery.of(context).size.height
            : contentHeight);

    return Consumer<EditorState>(
      builder: (context, editorState, child) {
        return Container(
          width: gutterWidth,
          height: height,
          color: widget
                  .editorConfigService.themeService.currentTheme?.background ??
              Colors.white,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(scrollbars: false),
            child: GestureDetector(
              onTapDown: _handleGutterTap,
              onPanStart: _handleGutterDragStart,
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
                      highlightColor: widget.editorConfigService.themeService
                              .currentTheme?.primary ??
                          Colors.blue,
                      editorConfigService: widget.editorConfigService,
                      editorLayoutService: widget.editorLayoutService,
                      editorState: editorState,
                      verticalOffset: widget.verticalScrollController.hasClients
                          ? widget.verticalScrollController.offset
                          : 0,
                      viewportHeight: height,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleGutterDragStart(DragStartDetails details) {
    _handleGutterSelection(details.localPosition.dy, false);
  }
}
