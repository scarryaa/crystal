import 'dart:async';
import 'dart:math';

import 'package:crystal/models/editor/events/event_models.dart';
import 'package:crystal/models/editor/lsp_models.dart';
import 'package:crystal/models/global_hover_state.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_event_bus.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/state/popup_state.dart';
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
  final PopupState _popupState = PopupState();
  OverlayEntry? _overlayEntry;
  Timer? _hoverDebounceTimer;
  String _lastHoveredWord = '';
  bool _isHoveringInfoPopup = false;
  bool _isHoveringDiagnosticsPopup = false;
  double diagnosticsHeight = 0;
  final bool _showDiagnosticsAbove = true;
  final double spaceBetweenPopups = 8.0;
  double _diagnosticsPopupTop = 0;
  bool _isMouseDown = false;
  final double _diagnosticsContentHeight = 0;
  final double _diagnosticMinHeight = 36.0;

  @override
  void initState() {
    super.initState();
    widget.globalHoverState.addListener(_onGlobalHoverStateChanged);
    EditorEventBus.on<TextEvent>().listen(_handleTextEvent);
    WidgetsBinding.instance.addPostFrameCallback(_addGlobalClickListener);
  }

  void _onGlobalHoverStateChanged() {
    if (!widget.globalHoverState.isActive(widget.row, widget.col)) {
      _hideOverlay();
    }
  }

  void _handleTextEvent(_) {
    _hideOverlay();
  }

  void _addGlobalClickListener(_) {
    if (mounted) {
      GestureBinding.instance.pointerRouter.addGlobalRoute(_handleGlobalClick);
    }
  }

  void _handleGlobalClick(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (_overlayEntry != null &&
          (!_popupState.isHoveringDiagnosticsPopup &&
              !_popupState.isHoveringInfoPopup)) {
        _hideOverlay();
      }
    }
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
    actualHeight = min(actualHeight, maxHeight);

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

    // Adjust diagnostics positioning using actual height instead of maxHeight
    if (hasContent && diagnostics.isNotEmpty) {
      _diagnosticsPopupTop = _showDiagnosticsAbove
          ? infoPopupTop - diagnosticsHeight - spaceBetweenPopups
          : infoPopupTop + actualHeight + spaceBetweenPopups;
    }

    if (_diagnosticsPopupTop < 0) {
      _diagnosticsPopupTop = infoPopupTop + actualHeight + spaceBetweenPopups;
    } else if (_diagnosticsPopupTop + diagnosticsHeight > screenSize.height) {
      _diagnosticsPopupTop =
          infoPopupTop - diagnosticsHeight - spaceBetweenPopups;
    }

    List<Widget> overlayWidgets = [];

    if (_popupState.showHoverInfoPopup) {
      overlayWidgets.add(
        Positioned(
          left: infoPopupLeft,
          top: infoPopupTop,
          child: _buildPopup(context, event),
        ),
      );
    }

    if (_popupState.showDiagnosticsPopup) {
      overlayWidgets.add(
        _buildDiagnosticsPopup(
          event.diagnostics,
          infoPopupLeft,
          _popupState.showHoverInfoPopup ? _diagnosticsPopupTop : infoPopupTop,
          _showDiagnosticsAbove,
          _popupState.showHoverInfoPopup ? maxHeight : 0,
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
    _popupState.setShowHoverInfoPopup(false);
    _popupState.setShowDiagnosticsPopup(false);
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
          if (!_popupState.isHoveringDiagnosticsPopup &&
              !_popupState.isHoveringInfoPopup &&
              !widget.isHoveringWord) {
            _handlePopupExit();
          }
          return const SizedBox.shrink();
        }

        final diagnostics = event.diagnostics;
        final hasHoverContent = event.content.trim().isNotEmpty;

        _popupState.setShowDiagnosticsPopup(diagnostics.isNotEmpty);
        _popupState.setShowHoverInfoPopup(hasHoverContent);

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showOverlay(context, event);
        });

        return const SizedBox.shrink();
      },
    );
  }

  void _handlePopupExit() {
    Future.delayed(const Duration(milliseconds: 50), () {
      if (!_isHoveringInfoPopup && !_isHoveringDiagnosticsPopup) {
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
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (event.content.isNotEmpty)
                              MarkdownBody(
                                data: event.content,
                                styleSheet: MarkdownStyleSheet(
                                  p: TextStyle(
                                    color: theme.text.withOpacity(0.9),
                                    fontSize: 13,
                                    fontFamily: widget
                                        .editorConfigService.config.fontFamily,
                                  ),
                                  code: TextStyle(
                                    color: theme.text.withOpacity(0.9),
                                    fontSize: 13,
                                    fontFamily: widget
                                        .editorConfigService.config.fontFamily,
                                    backgroundColor:
                                        theme.text.withOpacity(0.1),
                                  ),
                                  codeblockDecoration: BoxDecoration(
                                    color: theme.text.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                selectable: true,
                              ),
                          ]),
                    ),
                  ),
                ))
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
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: diagnosticsHeight,
                  minHeight:
                      min(_diagnosticMinHeight, _diagnosticsContentHeight),
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
                          )
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ));
  }

  @override
  void dispose() {
    widget.globalHoverState.removeListener(_onGlobalHoverStateChanged);
    _hideOverlay();
    _hoverDebounceTimer?.cancel();
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalClick);
    super.dispose();
  }
}
