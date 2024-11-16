import 'package:crystal/models/git_models.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/state/editor/editor_state.dart';
import 'package:flutter/material.dart';

class BlamePainter {
  final EditorConfigService editorConfigService;
  final EditorLayoutService editorLayoutService;
  final List<BlameLine> blameInfo;
  final double rightPadding;
  final EditorState editorState;

  final Map<String, TextPainter> _textPainterCache = {};

  BlamePainter({
    required this.editorConfigService,
    required this.editorLayoutService,
    required this.blameInfo,
    required this.editorState,
    this.rightPadding = 8.0,
  });

  void paint(
    Canvas canvas,
    Size size, {
    required int firstVisibleLine,
    required int lastVisibleLine,
  }) {
    if (blameInfo.isEmpty) return;

    final cursorLine = editorState.cursorLine;
    if (cursorLine < firstVisibleLine || cursorLine >= lastVisibleLine) return;
    if (cursorLine >= blameInfo.length) return;

    final lineHeight = editorLayoutService.config.lineHeight;

    final blame = blameInfo[cursorLine];
    final blameText = _formatBlameInfo(blame);
    final textPainter = _getTextPainter(blameText);

    // Calculate the current line's text width
    final lineText = editorState.buffer.getLine(cursorLine);
    final lineTextPainter = TextPainter(
      text: TextSpan(
        text: lineText,
        style: TextStyle(
          fontSize: editorConfigService.config.fontSize,
          fontFamily: editorConfigService.config.fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final double y = (cursorLine * lineHeight);
    final double x = lineTextPainter.width + 50;

    textPainter.paint(
      canvas,
      Offset(x, y + (lineHeight - textPainter.height) / 2),
    );

    lineTextPainter.dispose();
  }

  String _formatBlameInfo(BlameLine blame) {
    final authorName = blame.author.split(' ')[0];
    final timeAgo = _getTimeAgo(blame.timestamp);
    return '$authorName • $timeAgo';
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

  TextPainter _getTextPainter(String text) {
    if (_textPainterCache.containsKey(text)) {
      return _textPainterCache[text]!;
    }

    final style = TextStyle(
      color: editorConfigService.themeService.currentTheme?.primary ??
          Colors.grey[600]!,
      fontSize: editorConfigService.config.fontSize,
      fontFamily: editorConfigService.config.fontFamily,
    );

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();

    _textPainterCache[text] = textPainter;
    return textPainter;
  }

  void dispose() {
    for (final painter in _textPainterCache.values) {
      painter.dispose();
    }
    _textPainterCache.clear();
  }
}
