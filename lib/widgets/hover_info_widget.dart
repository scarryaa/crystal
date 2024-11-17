import 'dart:math';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/models/global_hover_state.dart';
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
  final int row;
  final int col;
  final GlobalHoverState globalHoverState;

  const HoverInfoWidget({
    super.key,
    required this.editorState,
    required this.editorLayoutService,
    required this.editorConfigService,
    required this.isHoveringWord,
    required this.onHoverPopup,
    required this.onLeavePopup,
    required this.row,
    required this.col,
    required this.globalHoverState,
  });

  @override
  State<HoverInfoWidget> createState() => _HoverInfoWidgetState();
}

class _HoverInfoWidgetState extends State<HoverInfoWidget> {
  bool _isHoveringPopup = false;
  final ScrollController _scrollController = ScrollController();
  double _popupLeft = 0;
  double _popupTop = 0;
  double _popupHeight = 0;
  double diagnosticsHeight = 0;
  bool _showDiagnosticsAbove = true;
  final double spaceBetweenPopups = 8.0;
  double _diagnosticsPopupTop = 0;
  OverlayEntry? _overlayEntry;
  String _lastHoveredWord = '';

  @override
  void initState() {
    super.initState();
    widget.globalHoverState.addListener(_onGlobalHoverStateChanged);
    EditorEventBus.on<TextEvent>().listen((_) {
      _hideOverlay();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        GestureBinding.instance.pointerRouter
            .addGlobalRoute(_handleGlobalClick);
      }
    });
  }

  void _onGlobalHoverStateChanged() {
    if (!widget.globalHoverState.isActive(widget.row, widget.col)) {
      _hideOverlay();
    }
  }

  void _handleGlobalClick(PointerEvent event) {
    if (event is PointerDownEvent) {
      // Check if click is within popup bounds
      if (_overlayEntry != null && _isHoveringPopup) {
        return;
      }
      _hideOverlay();
    }
  }

  void _showOverlay(BuildContext context, HoverEvent event) {
    // Check if current word matches last hovered word
    if (_lastHoveredWord != event.content) {
      _hideOverlay();
      _lastHoveredWord = event.content;
    }

    if (_overlayEntry != null) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    _hideOverlay();

    final Offset globalPosition = renderBox.localToGlobal(Offset.zero);
    final position = widget.editorLayoutService.getPositionForLineAndColumn(
      event.line,
      event.character,
    );

    final cursorX =
        position.dx - widget.editorState.scrollState.horizontalOffset;
    final cursorY = position.dy;

    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => Positioned(
        left: globalPosition.dx + cursorX,
        top: globalPosition.dy +
            cursorY +
            widget.editorLayoutService.config.lineHeight,
        child: _buildPopup(context, event),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<HoverEvent>(
      stream: EditorEventBus.on<HoverEvent>(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final event = snapshot.data!;

        if (event.line == -100 ||
            !widget.globalHoverState.isActive(widget.row, widget.col)) {
          if (!_isHoveringPopup && !widget.isHoveringWord) {
            _handlePopupExit();
          }
          return const SizedBox.shrink();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.isHoveringWord) {
            _showOverlay(context, event);
          }
        });

        return const SizedBox.shrink();
      },
    );
  }

  void _handlePopupExit() {
    if (!_isHoveringPopup) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hideOverlay();
        widget.onLeavePopup();
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
        ));
      });
    }
  }

  double _measureContentHeight(
      List<String> contents, double maxWidth, TextStyle style,
      {double maxHeight = 300.0}) {
    double totalHeight = 0;

    for (String content in contents) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: content, style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: maxWidth);

      totalHeight += textPainter.height + 4;

      // Early return if we exceed maxHeight
      if (totalHeight > maxHeight) {
        return maxHeight;
      }
    }

    return totalHeight;
  }

  Widget _buildPopup(BuildContext context, HoverEvent event) {
    const popupWidth = 400.0;
    const scrollbarWidth = 8.0;
    const defaultMaxPopupHeight = 300.0;
    const double minContentHeight = 110.0;

    final theme = widget.editorConfigService.themeService.currentTheme!;

    final TextStyle contentStyle = TextStyle(
      fontSize: 13,
      fontFamily: widget.editorConfigService.config.fontFamily,
    );

    double contentHeight =
        _measureContentHeight([event.content], popupWidth - 24, contentStyle);
    contentHeight = max(contentHeight, minContentHeight);
    contentHeight = min(contentHeight, defaultMaxPopupHeight);

    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _isHoveringPopup = true;
        });
        widget.onHoverPopup();
      },
      onExit: (_) {
        setState(() {
          _isHoveringPopup = false;
        });
        _handlePopupExit();
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: popupWidth,
          maxHeight: contentHeight,
          minHeight: contentHeight,
        ),
        decoration: BoxDecoration(
          color: theme.background,
          border: Border.all(color: theme.border),
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
    );
  }

  Widget _buildDiagnosticsPopup(List<Diagnostic> diagnostics, double left,
      double top, bool showAbove, double mainPopupHeight) {
    final theme = widget.editorConfigService.themeService.currentTheme!;

    return Positioned(
      left: left,
      top: _diagnosticsPopupTop,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              _isHoveringPopup = true;
              widget.editorState.setIsHoveringPopup(true);
              widget.onHoverPopup();
            });
          },
          onExit: (_) {
            setState(() {
              widget.editorState.setIsHoveringPopup(false);
              _isHoveringPopup = false;
            });
            _handlePopupExit();
          },
          child: Container(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: diagnosticsHeight,
            ),
            decoration: BoxDecoration(
              color: theme.background,
              border: Border.all(color: theme.border),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: theme.border.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: diagnostics
                      .map(
                        (diagnostic) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: theme.error,
                                size: 16,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  diagnostic.message,
                                  style: TextStyle(
                                    color: theme.text.withOpacity(0.9),
                                    fontSize: 12,
                                    fontFamily: widget
                                        .editorConfigService.config.fontFamily,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.globalHoverState.removeListener(_onGlobalHoverStateChanged);
    _hideOverlay();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalClick);
    super.dispose();
  }
}
