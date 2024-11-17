import 'dart:math';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

class HoverInfoWidget extends StatefulWidget {
  final EditorState editorState;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;
  final bool isHoveringWord;
  final Function() onHoverPopup;
  final Function() onLeavePopup;

  const HoverInfoWidget({
    super.key,
    required this.editorState,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.isHoveringWord,
    required this.onHoverPopup,
    required this.onLeavePopup,
  });

  @override
  State<HoverInfoWidget> createState() => _HoverInfoWidgetState();
}

class _HoverInfoWidgetState extends State<HoverInfoWidget> {
  bool _isHoveringPopup = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GestureBinding.instance.pointerRouter
            .addGlobalRoute(_handleGlobalClick);
      }
    });
  }

  double _measureContentHeight(String content, double maxWidth) {
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          fontSize: 13,
          fontFamily: widget.editorConfigService.config.fontFamily,
        ),
      ),
      maxLines: null,
      textDirection: TextDirection.ltr,
    );

    textPainter.layout(maxWidth: maxWidth);
    return textPainter.height + 24; // Add some padding
  }

  void _handleGlobalClick(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (!_isHoveringPopup) {
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HoverEvent>(
      stream: EditorEventBus.on<HoverEvent>(),
      builder: (context, snapshot) {
        // Don't proceed if no data and not hovering popup
        if (!snapshot.hasData) return const SizedBox.shrink();

        final event = snapshot.data!;

        // Keep showing if hovering popup, regardless of event
        if (_isHoveringPopup) {
          return _buildPopup(context, event);
        }

        // Hide if we get a hide event (-100) and not hovering popup
        if (event.line == -100) {
          return const SizedBox.shrink();
        }

        // Hide if not hovering word and not hovering popup
        if (!widget.isHoveringWord && !_isHoveringPopup) {
          return const SizedBox.shrink();
        }

        return _buildPopup(context, event);
      },
    );
  }

  Widget _buildPopup(BuildContext context, HoverEvent event) {
    final position = widget.editorLayoutService.getPositionForLineAndColumn(
      event.line,
      event.character,
    );

    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 400.0;
    const scrollbarWidth = 8.0;
    const defaultMaxPopupHeight = 300.0;
    final theme = widget.editorConfigService.themeService.currentTheme!;

    double cursorY =
        position.dy - widget.editorState.scrollState.verticalOffset;
    double spaceBelow = screenSize.height -
        cursorY -
        widget.editorLayoutService.config.lineHeight;
    double spaceAbove = cursorY;

    bool showAbove =
        spaceBelow < defaultMaxPopupHeight && spaceAbove > spaceBelow;
    double maxPopupHeight = showAbove
        ? min(defaultMaxPopupHeight, spaceAbove - 16)
        : min(defaultMaxPopupHeight, spaceBelow - 16);

    const double minimumHeight = 100.0;
    if (maxPopupHeight < minimumHeight) {
      // If we don't have enough space below or above, force it to show below
      // with minimum height, allowing scrolling if needed
      showAbove = false;
      maxPopupHeight = minimumHeight;
    }

    double contentHeight = _measureContentHeight(event.content, popupWidth);
    contentHeight = min(contentHeight, maxPopupHeight);

    double top;
    if (showAbove) {
      if (contentHeight < maxPopupHeight) {
        // If content is smaller than max height, position it just above the cursor
        top = cursorY - contentHeight + 20;
      } else {
        // If content is at max height, keep it at the calculated position
        top = cursorY - maxPopupHeight;
      }
    } else {
      top = cursorY + widget.editorLayoutService.config.lineHeight;
    }

    double left = position.dx - widget.editorState.scrollState.horizontalOffset;

    // Adjust horizontal position if it would go off screen
    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 16;
    }
    if (left < 16) {
      // Ensure some minimum padding from left edge
      left = 16;
    }

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              _isHoveringPopup = true;
              widget.onHoverPopup();
            });
          },
          onExit: (_) {
            setState(() {
              _isHoveringPopup = false;
              widget.onLeavePopup();
              if (!widget.isHoveringWord) {
                EditorEventBus.emit(HoverEvent(
                  line: -100,
                  character: -100,
                  content: '',
                ));
              }
            });
          },
          child: Container(
            constraints: BoxConstraints(
              maxWidth: popupWidth,
              maxHeight: contentHeight,
            ),
            decoration: BoxDecoration(
              color: theme.background,
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: RawScrollbar(
                    controller: _scrollController,
                    thickness: scrollbarWidth,
                    radius: const Radius.circular(0),
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: MarkdownBody(
                          data: event.content,
                          styleSheet: MarkdownStyleSheet(
                            p: TextStyle(
                              color: theme.text.withOpacity(0.9),
                              fontSize: 13,
                              fontFamily:
                                  widget.editorConfigService.config.fontFamily,
                            ),
                            code: TextStyle(
                              color: theme.text.withOpacity(0.9),
                              fontSize: 13,
                              fontFamily:
                                  widget.editorConfigService.config.fontFamily,
                              backgroundColor: theme.text.withOpacity(0.1),
                            ),
                            codeblockDecoration: BoxDecoration(
                              color: theme.text.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          selectable: true,
                        ),
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalClick);
    super.dispose();
  }
}
