import 'dart:async';

import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/git_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:crystal/widgets/editor/painter/painters/blame_painter.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BlameInfoWidget extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final List<BlameLine> blameInfo;
  final EditorState editorState;
  final Size size;
  final GitService gitService;

  const BlameInfoWidget({
    super.key,
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.blameInfo,
    required this.editorState,
    required this.size,
    required this.gitService,
  });

  @override
  State<BlameInfoWidget> createState() => _BlameInfoWidgetState();
}

class _BlameInfoWidgetState extends State<BlameInfoWidget> {
  Offset? _lastMousePosition;
  Offset? _currentMousePosition;
  OverlayEntry? _overlayEntry;
  BlameLine? _hoveredBlame;
  final Map<int, double> _lineWidths = {};
  late BlamePainter _blamePainter;
  bool _isHoveringPopup = false;
  Timer? _blameTimer;

  @override
  void initState() {
    super.initState();
    _blamePainter = BlamePainter(
      editorConfigService: widget.editorConfigService,
      editorLayoutService: widget.editorLayoutService,
      blameInfo: widget.blameInfo,
      editorState: widget.editorState,
    );

    widget.editorState.addListener(_onEditorStateChanged);

    GestureBinding.instance.pointerRouter.addGlobalRoute(_routeHandler);
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

  @override
  void didUpdateWidget(BlameInfoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.blameInfo != widget.blameInfo ||
        oldWidget.editorState != widget.editorState) {
      _lineWidths.clear();
      _blamePainter = BlamePainter(
        editorConfigService: widget.editorConfigService,
        editorLayoutService: widget.editorLayoutService,
        blameInfo: widget.blameInfo,
        editorState: widget.editorState,
      );
    }
  }

  double _getLineWidth(int lineIndex) {
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

    final width = textPainter.width;
    textPainter.dispose();
    return width;
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} "
        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }

  void _handleDelayedBlamePopup(
      BuildContext context, Offset position, BlameLine blame) {
    _blameTimer?.cancel();
    _blameTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showBlamePopup(context, position, blame);
      }
    });
  }

  void _showBlamePopup(BuildContext context, Offset position, BlameLine blame) {
    try {
      _lastMousePosition = position;

      if (_hoveredBlame == blame) return;
      _hideBlamePopup();
      _hoveredBlame = blame;

      final theme = widget.editorConfigService.themeService.currentTheme;

      // Get screen size
      final screenSize = MediaQuery.of(context).size;
      const popupWidth = 400.0;
      const popupHeight = 150.0;

      // Calculate position adjustments
      double left = position.dx;
      double top = position.dy + 10;

      // Adjust horizontal position if it would go offscreen
      if (left + popupWidth > screenSize.width) {
        left = screenSize.width - popupWidth - 16;
      }

      // Adjust vertical position if it would go offscreen
      if (top + popupHeight > screenSize.height) {
        top = position.dy - popupHeight + 20;
      }

      _overlayEntry = OverlayEntry(
          builder: (context) => Positioned(
                left: left,
                top: top,
                child: Material(
                  color: Colors.transparent,
                  child: MouseRegion(
                    onEnter: (_) => setState(() => _isHoveringPopup = true),
                    onExit: (_) => setState(() => _isHoveringPopup = false),
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
                                _buildAvatar(blame.email),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        blame.author,
                                        style: TextStyle(
                                          color: theme.text,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        _formatDateTime(blame.timestamp),
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
                                // Commit message row
                                if (blame.message.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      blame.message,
                                      style: TextStyle(
                                        color: theme.text.withOpacity(0.9),
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                // Commit hash row
                                Row(
                                  children: [
                                    MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () async {
                                          final repoUrl = await widget
                                              .gitService
                                              .getRepositoryUrl();
                                          if (repoUrl != null) {
                                            final uri = Uri.parse(
                                                '$repoUrl/commit/${blame.commitHash}');
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri);
                                            }
                                          }
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: theme.text.withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            blame.commitHash.substring(0, 7),
                                            style: TextStyle(
                                              color: theme.text,
                                              fontFamily: widget
                                                  .editorConfigService
                                                  .config
                                                  .fontFamily,
                                              fontSize: 12,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () {
                                        Clipboard.setData(ClipboardData(
                                            text: blame.commitHash));
                                      },
                                      tooltip: 'Copy commit hash',
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 24,
                                        minHeight: 24,
                                      ),
                                      color: theme.text.withOpacity(0.7),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ));

      Overlay.of(context).insert(_overlayEntry!);
    } catch (e) {
      print('Error showing popup: $e');
      _hideBlamePopup(); // Hide popup if anything fails
    }
  }

  Future<String> _getAvatarUrl(String email) async {
    // Use GitService's cache directly
    if (widget.gitService.avatarUrlCache.containsKey(email)) {
      return widget.gitService.avatarUrlCache[email]!;
    }

    try {
      if (_hoveredBlame == null) {
        return '';
      }
      final commitDetails =
          await widget.gitService.getCommitDetails(_hoveredBlame!.commitHash);
      return commitDetails.authorAvatarUrl;
    } catch (e) {
      print('Error getting avatar: $e');
      return '';
    }
  }

  Widget _buildAvatar(String email) {
    final theme = widget.editorConfigService.themeService.currentTheme!;
    return FutureBuilder<String>(
      future: _getAvatarUrl(email),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            backgroundColor: theme.text.withOpacity(0.2),
            radius: 16,
            backgroundImage: NetworkImage(snapshot.data!),
            onBackgroundImageError: (_, __) {},
            foregroundColor: Colors.transparent,
          );
        }
        return CircleAvatar(
          backgroundColor: theme.text.withOpacity(0.2),
          radius: 16,
          child: Text(
            email[0].toUpperCase(),
            style: TextStyle(
              color: theme.text,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        _currentMousePosition = event.position;
        final lineHeight = widget.editorLayoutService.config.lineHeight;
        final cursorLine = (event.localPosition.dy / lineHeight).floor();

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

          if (event.localPosition.dx >= blameStartX &&
              event.localPosition.dx <= blameStartX + blameTextWidth &&
              event.localPosition.dy >= blameStartY &&
              event.localPosition.dy <= blameEndY) {
            _handleDelayedBlamePopup(context, event.position, blame);
          } else {
            _hideBlamePopup();
          }
        } else {
          _hideBlamePopup();
        }
      },
      onExit: (_) {
        _blameTimer?.cancel();
        _hideBlamePopup();
      },
      child: CustomPaint(
        painter: _blamePainter,
      ),
    );
  }

  void _onEditorStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_routeHandler);
    _hideBlamePopupImmediately();
    super.dispose();
  }

  void _routeHandler(PointerEvent event) {
    if (event is PointerDownEvent) {
      if (!_isHoveringPopup) {
        _hideBlamePopupImmediately();
      }
    }
  }

  void _hideBlamePopupImmediately() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _hoveredBlame = null;
  }

  void _hideBlamePopup() {
    if (!_isHoveringPopup &&
        _lastMousePosition != null &&
        _currentMousePosition != null) {
      final distance = (_lastMousePosition! - _currentMousePosition!).distance;
      if (distance > 10) {
        _overlayEntry?.remove();
        _overlayEntry = null;
        _hoveredBlame = null;
      }
    }
  }
}
