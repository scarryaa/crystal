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
  final ScrollController _scrollController = ScrollController();
  bool _isHoveringInfoPopup = false;
  bool _isHoveringDiagnosticsPopup = false;
  double diagnosticsHeight = 0;
  final double spaceBetweenPopups = 8.0;
  OverlayEntry? _overlayEntry;
  String _lastHoveredWord = '';
  bool _isMouseDown = false;
  double _diagnosticsContentHeight = 0;
  final double _diagnosticItemPadding = 8.0;
  final double _diagnosticIconSize = 16.0;
  final double _diagnosticMinHeight = 36.0;
  bool _showDiagnosticsPopup = false;
  bool _showHoverInfoPopup = false;

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
      // Check if we're hovering over either popup
      if (_overlayEntry != null &&
          (_isHoveringDiagnosticsPopup || _isHoveringInfoPopup)) {
        // Don't hide if we're in the popups
        return;
      }
      _hideOverlay();
    }
  }

  void _calculateDiagnosticsHeight(List<Diagnostic> diagnostics) {
    const double maxDiagnosticsHeight = 200.0;

    // Calculate exact content height based on text wrapping
    _diagnosticsContentHeight = diagnostics.fold(0, (height, diagnostic) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: diagnostic.message,
          style: TextStyle(
            fontSize: 12,
            fontFamily: widget.editorConfigService.config.fontFamily,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      // Account for container width minus padding and icon
      textPainter.layout(maxWidth: 400 - 24 - _diagnosticIconSize - 8);
      return height +
          max(_diagnosticMinHeight,
              textPainter.height + _diagnosticItemPadding);
    });

    diagnosticsHeight = min(_diagnosticsContentHeight, maxDiagnosticsHeight);
  }

  void _showOverlay(BuildContext context, HoverEvent event) {
    if (_lastHoveredWord != event.content) {
      _hideOverlay();
      _lastHoveredWord = event.content;
    }

    if (_overlayEntry != null) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final Offset globalPosition = renderBox.localToGlobal(Offset.zero);
    final position = widget.editorLayoutService.getPositionForLineAndColumn(
      event.line,
      event.character,
    );
    final cursorX = position.dx;
    final cursorY = position.dy;

    final diagnostics = event.diagnostics;
    final hasContent = event.content.trim().isNotEmpty;

    if (!hasContent && diagnostics.isEmpty) return;

    const maxWidth = 400.0;
    const maxHeight = 300.0;
    const minHeight = 150.0;
    final screenSize = MediaQuery.of(context).size;

    // Calculate actual content height
    final contentStyle = TextStyle(
      fontSize: 13,
      fontFamily: widget.editorConfigService.config.fontFamily,
    );
    double actualHeight = _measureContentHeight(
        [event.content],
        maxWidth - 24, // Account for padding
        contentStyle);
    actualHeight = max(min(actualHeight, maxHeight), minHeight);

    double infoPopupLeft = globalPosition.dx + cursorX;
    double infoPopupTop = globalPosition.dy +
        cursorY +
        widget.editorLayoutService.config.lineHeight;

    if (event.diagnosticRange != null) {
      final startPosition =
          widget.editorLayoutService.getPositionForLineAndColumn(
        event.diagnosticRange!.start.line,
        event.diagnosticRange!.start.column,
      );
      final endPosition =
          widget.editorLayoutService.getPositionForLineAndColumn(
        event.diagnosticRange!.end.line,
        event.diagnosticRange!.end.column,
      );

      infoPopupLeft = globalPosition.dx + startPosition.dx;
      infoPopupTop = globalPosition.dy +
          startPosition.dy +
          widget.editorLayoutService.config.lineHeight;

      // Adjust for very small ranges (e.g., single character)
      if (endPosition.dx - startPosition.dx < 10) {
        infoPopupLeft -= 5; // Center the popup over the character
      }
    }

    // Adjust horizontal position if it goes off-screen
    if (infoPopupLeft + maxWidth > screenSize.width) {
      infoPopupLeft = screenSize.width - maxWidth - 10;
    }

    // Adjust vertical position if it goes off-screen using actual height
    if (infoPopupTop + actualHeight > screenSize.height) {
      infoPopupTop = globalPosition.dy + cursorY - actualHeight - 10;
    }

    // Calculate diagnostics popup position
    double diagnosticsPopupTop;
    if (hasContent && diagnostics.isNotEmpty) {
      diagnosticsPopupTop = infoPopupTop + actualHeight + spaceBetweenPopups;

      // Check if diagnostics popup goes off-screen at the bottom
      if (diagnosticsPopupTop + diagnosticsHeight > screenSize.height) {
        // Place diagnostics popup above the info popup
        diagnosticsPopupTop = infoPopupTop -
            diagnosticsHeight -
            actualHeight / 1.25 -
            spaceBetweenPopups;
      }
    } else {
      // If there's no info content, place diagnostics at the original position
      diagnosticsPopupTop = infoPopupTop;
    }

    List<Widget> overlayWidgets = [];

    if (_showHoverInfoPopup) {
      overlayWidgets.add(
        Positioned(
          left: infoPopupLeft,
          top: infoPopupTop,
          child: SizedBox(
            height: actualHeight,
            child: _buildPopup(context, event),
          ),
        ),
      );
    }

    if (_showDiagnosticsPopup) {
      overlayWidgets.add(
        _buildDiagnosticsPopup(
          event.diagnostics,
          infoPopupLeft,
          diagnosticsPopupTop,
          false,
          0,
        ),
      );
    }

    if (overlayWidgets.isNotEmpty) {
      _overlayEntry = OverlayEntry(
        builder: (BuildContext context) => Stack(children: overlayWidgets),
      );
      Overlay.of(context).insert(_overlayEntry!);
    }
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
          if (!_isHoveringDiagnosticsPopup &&
              !_isHoveringInfoPopup &&
              !widget.isHoveringWord) {
            _handlePopupExit();
          }
          return const SizedBox.shrink();
        }

        final diagnostics = event.diagnostics;
        final hasHoverContent = event.content.trim().isNotEmpty;
        final hasDiagnosticRange = event.diagnosticRange != null;

        _showDiagnosticsPopup = diagnostics.isNotEmpty;
        _showHoverInfoPopup = hasHoverContent || hasDiagnosticRange;

        _showDiagnosticsPopup = diagnostics.isNotEmpty;
        _showHoverInfoPopup = hasHoverContent;

        if (_showDiagnosticsPopup) {
          _calculateDiagnosticsHeight(diagnostics);
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (widget.isHoveringWord ||
              _isHoveringInfoPopup ||
              _isHoveringDiagnosticsPopup) {
            _showOverlay(context, event);
          } else {
            _hideOverlay();
          }
        });

        return const SizedBox.shrink();
      },
    );
  }

  void _handlePopupExit() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isHoveringInfoPopup &&
          !_isHoveringDiagnosticsPopup &&
          !widget.isHoveringWord) {
        _hideOverlay();
        widget.onLeavePopup();
        EditorEventBus.emit(HoverEvent(
          line: -100,
          character: -100,
          content: '',
          diagnostics: [],
        ));
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
    const popupWidth = 400.0;
    const scrollbarWidth = 6.0;
    const defaultMaxPopupHeight = 500.0;
    const double minContentHeight = 200.0;
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
          _isHoveringInfoPopup = true;
        });
        widget.onHoverPopup();
      },
      onExit: (_) {
        setState(() {
          _isHoveringInfoPopup = false;
        });
        if (!_isMouseDown) {
          _handlePopupExit();
        }
      },
      child: Listener(
        onPointerDown: (_) => _isMouseDown = true,
        onPointerUp: (_) => _isMouseDown = false,
        child: Container(
          width: popupWidth,
          constraints: BoxConstraints(
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
          child: Theme(
            data: Theme.of(context).copyWith(
              scrollbarTheme: ScrollbarThemeData(
                thumbColor: WidgetStateProperty.all(
                  theme.text.withOpacity(0.3),
                ),
                thickness: WidgetStateProperty.all(scrollbarWidth),
                radius: const Radius.circular(4),
                thumbVisibility: WidgetStateProperty.all(true),
                mainAxisMargin: 4,
              ),
            ),
            child: Scrollbar(
              controller: _scrollController,
              thickness: scrollbarWidth,
              radius: const Radius.circular(0),
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    top: 12,
                    bottom: 12,
                    right: 12 + scrollbarWidth,
                  ),
                  child: MarkdownBody(
                    data: event.content,
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: theme.text.withOpacity(0.9),
                        fontSize: 13,
                        height: 1.5,
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
                        border:
                            Border.all(color: theme.border.withOpacity(0.2)),
                      ),
                      blockquote: TextStyle(
                        color: theme.text.withOpacity(0.7),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      h1: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      h2: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      h3: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold),
                      listBullet: TextStyle(color: theme.text.withOpacity(0.9)),
                    ),
                    selectable: true,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiagnosticsPopup(List<Diagnostic> diagnostics, double left,
      double top, bool showAbove, double mainPopupHeight) {
    final theme = widget.editorConfigService.themeService.currentTheme!;
    const popupWidth = 400.0;

    return Positioned(
      left: left,
      top: top,
      child: Material(
        color: Colors.transparent,
        child: MouseRegion(
          onEnter: (_) {
            setState(() {
              _isHoveringDiagnosticsPopup = true;
              widget.editorState.setIsHoveringPopup(true);
            });
            widget.onHoverPopup();
          },
          onExit: (_) {
            setState(() {
              _isHoveringDiagnosticsPopup = false;
              widget.editorState.setIsHoveringPopup(false);
            });
            if (!_isMouseDown) {
              _handlePopupExit();
            }
          },
          child: Listener(
            onPointerDown: (_) => _isMouseDown = true,
            onPointerUp: (_) => _isMouseDown = false,
            child: Container(
              width: popupWidth,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: theme.background,
                border: Border.all(color: theme.border),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: theme.border.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
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
                            child: IntrinsicWidth(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: theme.error,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: SelectableText(
                                      diagnostic.message,
                                      style: TextStyle(
                                        color: theme.text.withOpacity(0.9),
                                        fontSize: 12,
                                        fontFamily: widget.editorConfigService
                                            .config.fontFamily,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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
      ),
    );
  }

  @override
  void dispose() {
    // Remove listener first
    widget.globalHoverState.removeListener(_onGlobalHoverStateChanged);

    // Hide overlay
    _hideOverlay();

    // Safely remove global route
    try {
      if (mounted) {
        GestureBinding.instance.pointerRouter
            .removeGlobalRoute(_handleGlobalClick);
      }
    } catch (e) {
      rethrow;
    }

    super.dispose();
  }
}
