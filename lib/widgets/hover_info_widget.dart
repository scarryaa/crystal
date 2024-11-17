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

  double _measureContentHeight(
      List<String> contents, double maxWidth, TextStyle style) {
    double totalHeight = 0;
    for (String content in contents) {
      final TextPainter textPainter = TextPainter(
        text: TextSpan(text: content, style: style),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout(maxWidth: maxWidth);
      totalHeight += textPainter.height + 4;
    }
    return totalHeight;
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
        if (!snapshot.hasData) return const SizedBox.shrink();

        final event = snapshot.data!;

        if (_isHoveringPopup) {
          return Stack(
            children: [
              _buildPopup(context, event),
              if (event.diagnostics.isNotEmpty)
                _buildDiagnosticsPopup(event.diagnostics, _popupLeft, _popupTop,
                    _showDiagnosticsAbove, _popupHeight),
            ],
          );
        }

        if (event.line == -100) return const SizedBox.shrink();

        if (!widget.isHoveringWord && !_isHoveringPopup) {
          return const SizedBox.shrink();
        }

        return MouseRegion(
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
          child: Stack(
            children: [
              _buildPopup(context, event),
              if (event.diagnostics.isNotEmpty)
                _buildDiagnosticsPopup(event.diagnostics, _popupLeft, _popupTop,
                    _showDiagnosticsAbove, _popupHeight),
            ],
          ),
        );
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
    const double minContentHeight = 110.0;

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
    diagnosticsHeight = _measureContentHeight(
        event.diagnostics.map((d) => d.message).toList(),
        popupWidth - 24,
        diagnosticStyle);

    if (contentHeight < minContentHeight) {
      contentHeight += 20.0;
    }

    double cursorY =
        position.dy - widget.editorState.scrollState.verticalOffset;
    double spaceBelow = screenSize.height -
        cursorY -
        widget.editorLayoutService.config.lineHeight;
    double spaceAbove = cursorY;

    double totalContentHeight =
        contentHeight + diagnosticsHeight + spaceBetweenPopups;
    bool showAbove = spaceBelow < totalContentHeight && spaceAbove > spaceBelow;
    double availableSpace = showAbove ? spaceAbove : spaceBelow;

    // Adjust heights based on available space
    if (totalContentHeight > availableSpace) {
      double ratio = (availableSpace - spaceBetweenPopups) / totalContentHeight;
      contentHeight *= ratio;
      diagnosticsHeight *= ratio;
    }

    contentHeight = min(contentHeight, defaultMaxPopupHeight);
    diagnosticsHeight = min(diagnosticsHeight, 100.0);

    double mainPopupTop;
    double diagnosticsPopupTop;
    if (showAbove) {
      diagnosticsPopupTop = cursorY - totalContentHeight;
      mainPopupTop =
          diagnosticsPopupTop + diagnosticsHeight + spaceBetweenPopups;
    } else {
      mainPopupTop = cursorY + widget.editorLayoutService.config.lineHeight;
      diagnosticsPopupTop = mainPopupTop + contentHeight + spaceBetweenPopups;
    }

    double left = position.dx - widget.editorState.scrollState.horizontalOffset;

    // Adjust horizontal position if it would go off screen
    if (left + popupWidth > screenSize.width) {
      left = screenSize.width - popupWidth - 16;
    }
    if (left < 16) {
      left = 16;
    }

    _popupLeft = left;
    _popupTop = mainPopupTop;
    _popupHeight = contentHeight;
    _showDiagnosticsAbove = showAbove;
    _diagnosticsPopupTop = diagnosticsPopupTop;

    return Positioned(
      left: left,
      top: _popupTop,
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

    // Calculate the position for the diagnostics popup
    double diagnosticsTop =
        showAbove ? top - diagnosticsHeight : top + mainPopupHeight;

    return Positioned(
      left: left,
      top: _diagnosticsPopupTop,
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
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_handleGlobalClick);
    super.dispose();
  }
}
