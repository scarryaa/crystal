import 'dart:math';

import 'package:crystal/models/editor/buffer.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_syntax_highlighter.dart';
import 'package:flutter/material.dart';

class MinimapCache {
  final Map<String, List<InlineSpan>> _highlightCache = {};
  final Map<String, int> _lineHashes = {};
  static const int maxSize = 1000;

  void clear() {
    _highlightCache.clear();
    _lineHashes.clear();
  }

  List<InlineSpan> getHighlights(
    String line,
    EditorSyntaxHighlighter highlighter,
  ) {
    final lineHash = line.hashCode;

    // Return cached highlights if line hasn't changed
    if (_lineHashes[line] == lineHash && _highlightCache.containsKey(line)) {
      return _highlightCache[line]!;
    }

    // Cache eviction if needed
    if (_highlightCache.length > maxSize) {
      final keysToRemove = _highlightCache.keys.take(maxSize ~/ 10).toList();
      for (final key in keysToRemove) {
        _highlightCache.remove(key);
        _lineHashes.remove(key);
      }
    }

    // Generate new highlights
    highlighter.highlight(line);
    final highlights = highlighter.buildTextSpan(line).children ?? [];

    // Cache the results
    _highlightCache[line] = highlights;
    _lineHashes[line] = lineHash;

    return highlights;
  }
}

class MinimapPainter extends CustomPainter {
  final Buffer buffer;
  final EditorLayoutService layoutService;
  final EditorConfigService editorConfigService;
  final double scale;
  final String fileName;
  final MinimapCache _cache = MinimapCache();
  late final EditorSyntaxHighlighter syntaxHighlighter;

  MinimapPainter({
    required this.buffer,
    required this.layoutService,
    required this.editorConfigService,
    required this.scale,
    required this.fileName,
  }) {
    syntaxHighlighter = EditorSyntaxHighlighter(
      editorLayoutService: layoutService,
      editorConfigService: editorConfigService,
      fileName: fileName,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final contentScale = scale * 0.1;
    final scaledLineHeight = layoutService.config.lineHeight * contentScale;
    final characterScale = scale * 0.5;

    for (int i = 0; i < buffer.lines.length; i++) {
      final line = buffer.lines[i];
      final yPosition = i * scaledLineHeight;

      if (yPosition > size.height) break;

      // Get cached highlights
      final highlights = _cache.getHighlights(line, syntaxHighlighter);

      double currentX = 0;

      // Draw each highlighted segment
      for (final span in highlights) {
        final textSpan = span as TextSpan;
        final paint = Paint()
          ..color = textSpan.style?.color ?? syntaxHighlighter.defaultTextColor
          ..strokeWidth = 1.0;

        final segmentWidth =
            (textSpan.text?.length ?? 0).toDouble() * characterScale;

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
  bool shouldRepaint(covariant MinimapPainter oldDelegate) {
    return buffer != oldDelegate.buffer ||
        fileName != oldDelegate.fileName ||
        scale != oldDelegate.scale;
  }

  void dispose() {
    _cache.clear();
  }
}

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
