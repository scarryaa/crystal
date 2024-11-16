import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/blame_painter.dart';
import 'package:flutter/material.dart';

class BlameInfoWidget extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final List<BlameLine> blameInfo;
  final EditorState editorState;
  final Size size;

  const BlameInfoWidget({
    super.key,
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.blameInfo,
    required this.editorState,
    required this.size,
  });

  @override
  State<BlameInfoWidget> createState() => _BlameInfoWidgetState();
}

class _BlameInfoWidgetState extends State<BlameInfoWidget> {
  OverlayEntry? _overlayEntry;
  BlameLine? _hoveredBlame;
  final Map<int, double> _lineWidths = {};
  late BlamePainter _blamePainter;

  @override
  void initState() {
    super.initState();
    _blamePainter = BlamePainter(
      editorConfigService: widget.editorConfigService,
      editorLayoutService: widget.editorLayoutService,
      blameInfo: widget.blameInfo,
      editorState: widget.editorState,
    );
  }

  double _getBlameTextWidth(BlameLine blame) {
    final blameText =
        '${blame.author.split(' ')[0]} • ${_getTimeAgo(blame.timestamp)}';
    return _blamePainter.getBlameTextWidth(blameText);
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()}y';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()}mo';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }

  double _getLineWidth(int lineIndex) {
    if (!_lineWidths.containsKey(lineIndex)) {
      final lineText = widget.editorState.buffer.getLine(lineIndex);
      final textPainter = TextPainter(
        text: TextSpan(
          text: lineText,
          style: TextStyle(
            fontSize: widget.editorConfigService.config.fontSize,
            fontFamily: widget.editorConfigService.config.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      _lineWidths[lineIndex] = textPainter.width;
      textPainter.dispose();
    }
    return _lineWidths[lineIndex]!;
  }

  void _showBlamePopup(BuildContext context, Offset position, BlameLine blame) {
    if (_hoveredBlame == blame) return;
    _hideBlamePopup();
    _hoveredBlame = blame;

    final theme = widget.editorConfigService.themeService.currentTheme;

    // Get screen size
    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 400.0;
    const popupHeight = 200.0; // Approximate height, adjust as needed

    // Calculate position adjustments
    double left = position.dx;
    double top = position.dy + 20;

    // Adjust horizontal position if it would go offscreen
    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 16; // 16px padding from edge
    }

    // Adjust vertical position if it would go offscreen
    if (top + popupHeight > screenSize.height) {
      top = position.dy - popupHeight - 8; // Show above cursor
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: left,
        top: top,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: popupWidth),
            decoration: BoxDecoration(
              color: theme!.background,
              border: Border.all(
                color: theme.border,
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.border.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.text.withOpacity(0.1),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      topRight: Radius.circular(8),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: theme.text.withOpacity(0.2),
                        radius: 16,
                        child: Text(
                          blame.author[0].toUpperCase(),
                          style: TextStyle(
                            color: theme.text,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              blame.author,
                              style: TextStyle(
                                color: theme.text,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              blame.timestamp.toString(),
                              style: TextStyle(
                                color: theme.text.withOpacity(0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Content
                Container(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Commit hash
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.text.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              blame.commitHash.substring(0, 7),
                              style: TextStyle(
                                color: theme.text,
                                fontFamily: widget
                                    .editorConfigService.config.fontFamily,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Commit message
                      Text(
                        blame.message,
                        style: TextStyle(
                          color: theme.text,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        final lineHeight = widget.editorLayoutService.config.lineHeight;
        final cursorLine = (event.localPosition.dy / lineHeight).floor();

        // Check if hovering on the same line as the editor cursor
        if (cursorLine ==
                widget.editorState.editorCursorManager.cursors.first.line &&
            cursorLine >= 0 &&
            cursorLine < widget.blameInfo.length) {
          final lineWidth = _getLineWidth(cursorLine);
          final blameStartX = lineWidth + 50;
          final blame = widget.blameInfo[cursorLine];
          final blameTextWidth = _getBlameTextWidth(blame);
          final blameStartY =
              cursorLine * widget.editorLayoutService.config.lineHeight;
          final blameEndY =
              blameStartY + widget.editorLayoutService.config.lineHeight;

          // Only show popup if mouse is within the blame text area
          if (event.localPosition.dx >= blameStartX &&
              event.localPosition.dx <= blameStartX + blameTextWidth &&
              event.localPosition.dy >= blameStartY &&
              event.localPosition.dy <= blameEndY) {
            _showBlamePopup(context, event.position, blame);
          } else {
            _hideBlamePopup();
          }
        } else {
          _hideBlamePopup();
        }
      },
      onExit: (_) {
        _hideBlamePopup();
      },
      child: CustomPaint(
        painter: _blamePainter,
      ),
    );
  }

  @override
  void didUpdateWidget(BlameInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blameInfo != widget.blameInfo ||
        oldWidget.editorState != widget.editorState) {
      _blamePainter = BlamePainter(
        editorConfigService: widget.editorConfigService,
        editorLayoutService: widget.editorLayoutService,
        blameInfo: widget.blameInfo,
        editorState: widget.editorState,
      );
    }
  }

  @override
  void dispose() {
    _hideBlamePopup();
    super.dispose();
  }

  void _hideBlamePopup() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredBlame = null;
  }
}
