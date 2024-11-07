import 'package:crystal/models/highlighted_text.dart';
import 'package:crystal/models/languages/dart.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:flutter/material.dart';

class EditorSyntaxHighlighter {
  final List<HighlightedText> highlightedText = [];
  final Language language;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  EditorSyntaxHighlighter({
    Language? language,
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : language = language ?? Dart();

  static const keywordColor = Colors.blue;
  static const typeColor = Colors.teal;
  static Color stringColor = Colors.green[700]!;
  static const commentColor = Colors.grey;
  static const numberColor = Colors.orange;
  static const symbolColor = Colors.purple;
  static const defaultTextColor = Colors.black;

  void highlight(String text) {
    highlightedText.clear();

    final List<(int, int)> commentRegions = [];

    // Handle multi-line comments
    for (final match in language.commentMulti.allMatches(text)) {
      highlightedText.add(HighlightedText(
        text: match.group(0)!,
        color: commentColor,
        start: match.start,
        end: match.end,
      ));
      commentRegions.add((match.start, match.end));
    }

    // Handle single-line comments
    for (final match in language.commentSingle.allMatches(text)) {
      highlightedText.add(HighlightedText(
        text: match.group(0)!,
        color: commentColor,
        start: match.start,
        end: match.end,
      ));
      commentRegions.add((match.start, match.end));
    }

    bool isInComment(int position) {
      return commentRegions
          .any((region) => position >= region.$1 && position < region.$2);
    }

    // Handle string literals (but not in comments)
    _highlightPattern(text, language.stringLiteral, stringColor,
        skipIf: isInComment);

    // Handle number literals (but not in comments)
    _highlightPattern(text, language.numberLiteral, numberColor,
        skipIf: isInComment);

    // Handle keywords (but not in comments)
    for (final keyword in language.keywords) {
      _highlightWord(text, keyword, keywordColor, skipIf: isInComment);
    }

    // Handle types (but not in comments)
    for (final type in language.types) {
      _highlightWord(text, type, typeColor, skipIf: isInComment);
    }

    // Handle symbols (but not in comments)
    for (final symbol in language.symbols) {
      _highlightSymbol(text, symbol, symbolColor, skipIf: isInComment);
    }

    // Sort highlights by start position
    highlightedText.sort((a, b) => a.start.compareTo(b.start));
  }

  void _highlightPattern(String text, RegExp pattern, Color color,
      {bool Function(int)? skipIf}) {
    final matches = pattern.allMatches(text);
    for (final match in matches) {
      if (skipIf == null || !skipIf(match.start)) {
        if (!_isRegionHighlighted(match.start, match.end)) {
          highlightedText.add(HighlightedText(
            text: match.group(0)!,
            color: color,
            start: match.start,
            end: match.end,
          ));
        }
      }
    }
  }

  void _highlightWord(String text, String word, Color color,
      {bool Function(int)? skipIf}) {
    final pattern = RegExp('\\b$word\\b');
    final matches = pattern.allMatches(text);
    for (final match in matches) {
      if (skipIf == null || !skipIf(match.start)) {
        if (!_isRegionHighlighted(match.start, match.end)) {
          highlightedText.add(HighlightedText(
            text: word,
            color: color,
            start: match.start,
            end: match.end,
          ));
        }
      }
    }
  }

  void _highlightSymbol(String text, String symbol, Color color,
      {bool Function(int)? skipIf}) {
    int index = 0;
    while (true) {
      index = text.indexOf(symbol, index);
      if (index == -1) break;
      if (skipIf == null || !skipIf(index)) {
        if (!_isRegionHighlighted(index, index + symbol.length)) {
          highlightedText.add(HighlightedText(
            text: symbol,
            color: color,
            start: index,
            end: index + symbol.length,
          ));
        }
      }
      index += symbol.length;
    }
  }

  bool _isRegionHighlighted(int start, int end) {
    return highlightedText.any((highlight) =>
        (start >= highlight.start && start < highlight.end) ||
        (end > highlight.start && end <= highlight.end));
  }

  TextSpan buildTextSpan(String text) {
    if (highlightedText.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(
          color: defaultTextColor,
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          height: editorLayoutService.config.lineHeightMultiplier,
        ),
      );
    }

    final List<TextSpan> spans = [];
    int currentIndex = 0;

    for (final highlight in highlightedText) {
      if (currentIndex < highlight.start) {
        spans.add(TextSpan(
          text: text.substring(currentIndex, highlight.start),
          style: TextStyle(
            color: defaultTextColor,
            fontFamily: editorConfigService.config.fontFamily,
            fontSize: editorConfigService.config.fontSize,
            height: editorLayoutService.config.lineHeightMultiplier,
          ),
        ));
      }
      spans.add(TextSpan(
        text: highlight.text,
        style: TextStyle(
          color: highlight.color,
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          height: editorLayoutService.config.lineHeightMultiplier,
        ),
      ));
      currentIndex = highlight.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(
          color: defaultTextColor,
          fontFamily: editorConfigService.config.fontFamily,
          fontSize: editorConfigService.config.fontSize,
          height: editorLayoutService.config.lineHeightMultiplier,
        ),
      ));
    }

    return TextSpan(children: spans);
  }
}
