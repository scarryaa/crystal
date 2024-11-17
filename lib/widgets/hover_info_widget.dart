import 'dart:math';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
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
  double _popupLeft = 0;
  double _popupTop = 0;
  double _popupHeight = 0;
  double diagnosticsHeight = 0;
  bool _showDiagnosticsAbove = true;
  final double spaceBetweenPopups = 8.0;
  double _diagnosticsPopupTop = 0;
  OverlayEntry? _overlayEntry;

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
      _hideOverlay();
    }
  }

  void _showOverlay(BuildContext context, HoverEvent event) {
    _hideOverlay();
    _overlayEntry = OverlayEntry(
      builder: (BuildContext context) => Stack(
        children: [
          _buildPopup(context, event),
          if (event.diagnostics.isNotEmpty)
            _buildDiagnosticsPopup(event.diagnostics, _popupLeft, _popupTop,
                _showDiagnosticsAbove, _popupHeight),
        ],
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

        if (event.line == -100) {
          _hideOverlay();
          return const SizedBox.shrink();
        }

        if (widget.isHoveringWord || _isHoveringPopup) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showOverlay(context, event);
          });
        } else {
          _hideOverlay();
        }

        return const SizedBox.shrink();
      },
    );
  }

  void _handlePopupExit() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isHoveringPopup) {
        setState(() {
          widget.onLeavePopup();
          if (!widget.isHoveringWord) {
            EditorEventBus.emit(HoverEvent(
              line: -100,
              character: -100,
              content: '',
            ));
          }
        });
      }
    });
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
    final position = widget.editorLayoutService.getPositionForLineAndColumn(
      event.line,
      event.character,
    );

    final screenSize = MediaQuery.of(context).size;
    const popupWidth = 400.0;
    const scrollbarWidth = 8.0;
    const defaultMaxPopupHeight = 300.0;
    const double minContentHeight = 110.0;
    const double padding = 0.0;

    final theme = widget.editorConfigService.themeService.currentTheme!;

    final TextStyle contentStyle = TextStyle(
      fontSize: 13,
      fontFamily: widget.editorConfigService.config.fontFamily,
    );

    final TextStyle diagnosticStyle = TextStyle(
      fontSize: 12,
      fontFamily: widget.editorConfigService.config.fontFamily,
    );

    double contentHeight =
        _measureContentHeight([event.content], popupWidth - 24, contentStyle);
    contentHeight = max(contentHeight, minContentHeight);
    contentHeight = min(contentHeight, defaultMaxPopupHeight);

    diagnosticsHeight = event.diagnostics.isNotEmpty
        ? _measureContentHeight(
            event.diagnostics.map((d) => d.message).toList(),
            popupWidth - 24,
            diagnosticStyle)
        : 0;
    diagnosticsHeight = min(diagnosticsHeight, 100.0);

    double totalContentHeight = contentHeight +
        (event.diagnostics.isNotEmpty
            ? diagnosticsHeight + spaceBetweenPopups
            : 0);

    // Calculate available space
    double cursorY =
        position.dy - widget.editorState.scrollState.verticalOffset;
    double spaceBelow = screenSize.height -
        cursorY -
        widget.editorLayoutService.config.lineHeight;
    double spaceAbove = cursorY;

    // Decide whether to show above or below
    bool showAbove = spaceBelow < totalContentHeight && spaceAbove > spaceBelow;

    // Adjust content heights if necessary
    double availableSpace = showAbove ? spaceAbove : spaceBelow;
    if (totalContentHeight > availableSpace - padding * 2) {
      double ratio = (availableSpace - padding * 2) / totalContentHeight;
      contentHeight *= ratio;
      diagnosticsHeight *= ratio;
      totalContentHeight = availableSpace - padding * 2;
    }

    // Calculate vertical positions
    double mainPopupTop, diagnosticsPopupTop;
    if (showAbove) {
      mainPopupTop = max(padding, cursorY - totalContentHeight - padding);
      diagnosticsPopupTop = mainPopupTop + contentHeight + spaceBetweenPopups;
    } else {
      mainPopupTop =
          cursorY + widget.editorLayoutService.config.lineHeight + padding;
      double bottomEdge = mainPopupTop + totalContentHeight;
      if (bottomEdge > screenSize.height - padding) {
        double offset = bottomEdge - (screenSize.height - padding);
        mainPopupTop -= offset;
      }
      diagnosticsPopupTop = mainPopupTop + contentHeight + spaceBetweenPopups;
    }

    // Calculate horizontal position
    double left = position.dx - widget.editorState.scrollState.horizontalOffset;
    left = max(padding, min(left, screenSize.width - popupWidth - padding));

    // Update state variables
    _popupLeft = left;
    _popupTop = mainPopupTop;
    _popupHeight = contentHeight;
    _showDiagnosticsAbove = showAbove;
    _diagnosticsPopupTop = diagnosticsPopupTop;

    return Positioned(
        left: left,
        top: _popupTop,
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
              _isHoveringPopup = false;
              widget.editorState.setIsHoveringPopup(false);
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
        ));
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
    void routeHandler(PointerEvent event) {
      if (event is PointerDownEvent) {
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
        ));
      }
    }

    // Remove only if we previously added it
    try {
      GestureBinding.instance.pointerRouter
          .removeGlobalRoute(_handleGlobalClick);
    } catch (e) {
      // Ignore if route wasn't found
    }

    super.dispose();
  }
}
