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
    final theme = widget.editorConfigService.themeService.currentTheme!;

    double left = position.dx - widget.editorState.scrollState.horizontalOffset;
    double top = position.dy +
        widget.editorLayoutService.config.lineHeight -
        widget.editorState.scrollState.verticalOffset;

    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 16;
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
              // Only emit hide event if we're not hovering the word
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
            constraints: const BoxConstraints(maxWidth: popupWidth),
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
            child: Container(
              padding: const EdgeInsets.all(12),
              child: MarkdownBody(
                data: event.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: theme.text.withOpacity(0.9),
                    fontSize: 13,
                    fontFamily: widget.editorConfigService.config.fontFamily,
                  ),
                  code: TextStyle(
                    color: theme.text.withOpacity(0.9),
                    fontSize: 13,
                    fontFamily: widget.editorConfigService.config.fontFamily,
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
      ),
    );
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalClick);
    super.dispose();
  }
}
