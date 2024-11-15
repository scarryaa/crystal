import 'dart:math';

import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class Minimap extends StatefulWidget {
  final Buffer buffer;
  final double viewportHeight;
  final double scrollPosition;
  final EditorLayoutService layoutService;
  final EditorConfigService editorConfigService;
  final Function(double) onScroll;
  final double totalContentHeight;
  final String fileName;

  const Minimap({
    super.key,
    required this.buffer,
    required this.viewportHeight,
    required this.scrollPosition,
    required this.layoutService,
    required this.editorConfigService,
    required this.onScroll,
    required this.totalContentHeight,
    required this.fileName,
  });

  @override
  State<Minimap> createState() => _MinimapState();
}

class _MinimapState extends State<Minimap> {
  late double _currentScrollPosition = 0;

  @override
  void didUpdateWidget(Minimap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollPosition != widget.scrollPosition) {
      setState(() {
        _currentScrollPosition = widget.scrollPosition;
      });
    }
  }

  void _handleMinimapInteraction(
    DragUpdateDetails? details,
    TapDownDetails? tapDetails,
    double editorHeight,
    double minimapContentHeight,
  ) {
    final totalContentHeight =
        widget.buffer.lines.length * widget.layoutService.config.lineHeight;

    // Only allow interaction if content is taller than viewport
    if (totalContentHeight <=
        widget.viewportHeight +
            EditorLayoutService.instance.config.verticalPadding) {
      setState(() {
        _currentScrollPosition = 0;
      });
      widget.onScroll(0);
      return;
    }

    final maxScroll = totalContentHeight -
        widget.viewportHeight +
        EditorLayoutService.instance.config.verticalPadding;

    // Get position from either drag or tap
    final position =
        (details?.localPosition.dy ?? tapDetails?.localPosition.dy ?? 0.0);

    // Calculate the ratio of the tap position to the minimap height
    final tapRatio = position / minimapContentHeight;

    setState(() {
      _currentScrollPosition =
          (tapRatio * totalContentHeight - widget.viewportHeight / 2)
              .clamp(0.0, maxScroll);
    });

    widget.onScroll(_currentScrollPosition);
  }

  @override
  Widget build(BuildContext context) {
    const minimapWidth = 100.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final editorHeight = constraints.maxHeight;
        final totalContentHeight =
            widget.buffer.lines.length * widget.layoutService.config.lineHeight;
        final scale = min(editorHeight / totalContentHeight, 1.0);
        final minimapContentHeight = totalContentHeight * scale * 0.1;

        return GestureDetector(
          onVerticalDragUpdate: (details) => _handleMinimapInteraction(
            details,
            null,
            editorHeight,
            minimapContentHeight,
          ),
          onTapDown: (details) => _handleMinimapInteraction(
            null,
            details,
            editorHeight,
            minimapContentHeight,
          ),
          child: Container(
            width: minimapWidth,
            height: editorHeight,
            color: widget
                .editorConfigService.themeService.currentTheme!.background,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  child: SizedBox(
                    width: minimapWidth,
                    height: minimapContentHeight,
                    child: CustomPaint(
                      size: Size(minimapWidth, minimapContentHeight),
                      painter: MinimapPainter(
                        buffer: widget.buffer,
                        layoutService: widget.layoutService,
                        editorConfigService: widget.editorConfigService,
                        scale: scale,
                        fileName: widget.fileName,
                      ),
                    ),
                  ),
                ),
                _buildViewportIndicator(
                  minimapContentHeight,
                  totalContentHeight,
                  editorHeight,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildViewportIndicator(double minimapContentHeight,
      double totalContentHeight, double editorHeight) {
    final viewportIndicatorHeight = max(
      (widget.viewportHeight / totalContentHeight) * minimapContentHeight,
      30.0,
    );

    final indicatorPosition = totalContentHeight <= widget.viewportHeight
        ? 0.0
        : (_currentScrollPosition /
                (totalContentHeight - widget.viewportHeight)) *
            minimapContentHeight;

    return Positioned(
      top: indicatorPosition,
      child: Container(
        width: 100.0,
        height: viewportIndicatorHeight,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.2),
          border: Border.all(color: Colors.grey),
        ),
      ),
    );
  }
}

class MinimapPainter extends CustomPainter {
  final Buffer buffer;
  final EditorLayoutService layoutService;
  final EditorConfigService editorConfigService;
  final double scale;
  final String fileName;

  MinimapPainter({
    required this.buffer,
    required this.layoutService,
    required this.editorConfigService,
    required this.scale,
    required this.fileName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final syntaxHighlighter = EditorSyntaxHighlighter(
        editorLayoutService: layoutService,
        editorConfigService: editorConfigService,
        fileName: fileName);

    // Use small scale directly without height adjustment
    final contentScale = scale * 0.1;
    final scaledLineHeight = layoutService.config.lineHeight * contentScale;
    final characterScale = scale * 0.5;

    for (int i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final yPosition = i * scaledLineHeight;

      // Skip lines that would be drawn outside the visible area
      if (yPosition > size.height) break;

      // Highlight the current line
      syntaxHighlighter.highlight(line);
      final highlights = syntaxHighlighter.highlightedText;

      double currentX = 0;

      // Draw each highlighted segment
      for (final highlight in highlights) {
        final paint = Paint()
          ..color = highlight.color
          ..strokeWidth = 1.0;

        final segmentWidth = highlight.text.length.toDouble() * characterScale;

        canvas.drawLine(
          Offset(currentX, yPosition),
          Offset(currentX + segmentWidth, yPosition),
          paint,
        );

        currentX += segmentWidth;
      }

      // Draw any remaining unhighlighted text
      if (currentX < line.length * characterScale) {
        final paint = Paint()
          ..color = syntaxHighlighter.defaultTextColor
          ..strokeWidth = 1.0;

        canvas.drawLine(
          Offset(currentX, yPosition),
          Offset(line.length.toDouble() * characterScale, yPosition),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
