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
    final firstVisibleLine = (widget.verticalScrollController.offset /
            widget.editorLayoutService.config.lineHeight)
        .floor();

    double adjustedY = y + widget.verticalScrollController.offset;
    int visualLine = adjustedY ~/ widget.editorLayoutService.config.lineHeight;

    // Convert visual line to buffer line accounting for folded regions
    int currentVisualLine = 0;
    int bufferLine = firstVisibleLine;

    while (currentVisualLine < (visualLine - firstVisibleLine) &&
        bufferLine < editorState.buffer.lineCount) {
      if (!editorState.foldingState.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    // Skip any hidden lines
    while (bufferLine < editorState.buffer.lineCount &&
        editorState.foldingState.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return bufferLine.clamp(0, editorState.buffer.lineCount - 1);
  }

  int _getBufferLine(int visualLine) {
    int currentVisualLine = 0;
    int bufferLine = 0;

    while (currentVisualLine < visualLine &&
        bufferLine < editorState.buffer.lineCount) {
      if (!editorState.foldingState.isLineHidden(bufferLine)) {
        currentVisualLine++;
      }
      bufferLine++;
    }

    // Skip hidden lines
    while (bufferLine < editorState.buffer.lineCount &&
        editorState.foldingState.isLineHidden(bufferLine)) {
      bufferLine++;
    }

    return min(bufferLine, editorState.buffer.lineCount - 1);
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

    // Check if tap is in folding indicator area
    if (details.localPosition.dx < 20) {
      _handleFoldingIconTap(line);
    } else {
      _handleGutterSelection(details.localPosition.dy, false);
    }
  }

  bool _isFoldable(int line) {
    if (line >= editorState.buffer.lines.length) return false;

    final currentLine = editorState.buffer.lines[line].trim();
    if (currentLine.isEmpty) return false;

    // Check if line ends with block starter
    if (!currentLine.endsWith('{') &&
        !currentLine.endsWith('(') &&
        !currentLine.endsWith('[')) {
      return false;
    }

    final currentIndent = _getIndentation(editorState.buffer.lines[line]);

    // Look ahead for valid folding range
    int nextLine = line + 1;
    bool hasContent = false;

    while (nextLine < editorState.buffer.lines.length) {
      final nextLineText = editorState.buffer.lines[nextLine];
      if (nextLineText.trim().isEmpty) {
        nextLine++;
        continue;
      }

      final nextIndent = _getIndentation(nextLineText);
      if (nextIndent <= currentIndent) {
        return hasContent;
      }
      hasContent = true;
      nextLine++;
    }

    return false;
  }

  int _getIndentation(String line) {
    final match = RegExp(r'[^\s]').firstMatch(line);
    return match?.start ?? -1;
  }

  void _handleFoldingIconTap(int line) {
    // First convert the visual line to buffer line correctly
    final firstVisibleLine = (widget.verticalScrollController.offset /
            widget.editorLayoutService.config.lineHeight)
        .floor();

    // Calculate visual offset for proper positioning
    int visualOffset = 0;
    for (int i = 0; i < firstVisibleLine; i++) {
      if (!editorState.foldingState.isLineHidden(i)) {
        visualOffset++;
      }
    }

    if (_isFoldable(line) || editorState.foldingState.isLineFolded(line)) {
      final endLine = _findFoldingEndLine(line);
      if (endLine != null) {
        editorState.toggleFold(line, endLine);
      }
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

  @override
  Widget build(BuildContext context) {
    double contentHeight =
        getVisibleLineCount() * widget.editorLayoutService.config.lineHeight +
            widget.editorLayoutService.config.verticalPadding;

    double height = max(
        contentHeight,
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
              onPanStart: (details) =>
                  _handleGutterSelection(details.localPosition.dy, false),
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
}
