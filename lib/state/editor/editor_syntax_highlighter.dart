import 'package:crystal/constants/editor_constants.dart';
import 'package:crystal/models/highlighted_text.dart';
import 'package:crystal/models/languages/dart.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:flutter/material.dart';

class EditorSyntaxHighlighter {
  final List<HighlightedText> highlightedText = [];
  final Language language;

  EditorSyntaxHighlighter({Language? language}) : language = language ?? Dart();

  static const keywordColor = Colors.blue;
  static const typeColor = Colors.teal;
  static Color stringColor = Colors.green[700]!;
  static const commentColor = Colors.grey;
  static const numberColor = Colors.orange;
  static const symbolColor = Colors.purple;
  static const defaultTextColor = Colors.black;

  void highlight(String text) {
    highlightedText.clear();
    // Handle multi-line comments first
    _highlightPattern(text, language.commentMulti, commentColor);
    // Handle single-line comments
    _highlightPattern(text, language.commentSingle, commentColor);
    // Handle string literals
    _highlightPattern(text, language.stringLiteral, stringColor);
    // Handle number literals
    _highlightPattern(text, language.numberLiteral, numberColor);
    // Handle keywords
    for (final keyword in language.keywords) {
      _highlightWord(text, keyword, keywordColor);
    }
    // Handle types
    for (final type in language.types) {
      _highlightWord(text, type, typeColor);
    }
    // Handle symbols
    for (final symbol in language.symbols) {
      _highlightSymbol(text, symbol, symbolColor);
    }
    // Sort highlights by start position
    highlightedText.sort((a, b) => a.start.compareTo(b.start));
  }

  void _highlightPattern(String text, RegExp pattern, Color color) {
    final matches = pattern.allMatches(text);
    for (final match in matches) {
      highlightedText.add(HighlightedText(
        text: match.group(0)!,
        color: color,
        start: match.start,
        end: match.end,
      ));
    }
  }

  void _highlightWord(String text, String word, Color color) {
    final pattern = RegExp('\\b$word\\b');
    final matches = pattern.allMatches(text);
    for (final match in matches) {
      // Check if this region is already highlighted
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

  void _highlightSymbol(String text, String symbol, Color color) {
    int index = 0;
    while (true) {
      index = text.indexOf(symbol, index);
      if (index == -1) break;
      if (!_isRegionHighlighted(index, index + symbol.length)) {
        highlightedText.add(HighlightedText(
          text: symbol,
          color: color,
          start: index,
          end: index + symbol.length,
        ));
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
          fontFamily: EditorConstants.fontFamily,
          fontSize: EditorConstants.fontSize,
          height: EditorConstants.lineHeightRatio,
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
            fontFamily: EditorConstants.fontFamily,
            fontSize: EditorConstants.fontSize,
            height: EditorConstants.lineHeightRatio,
          ),
        ));
      }
      spans.add(TextSpan(
        text: highlight.text,
        style: TextStyle(
          color: highlight.color,
          fontFamily: EditorConstants.fontFamily,
          fontSize: EditorConstants.fontSize,
          height: EditorConstants.lineHeightRatio,
        ),
      ));
      currentIndex = highlight.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(
        text: text.substring(currentIndex),
        style: TextStyle(
          color: defaultTextColor,
          fontFamily: EditorConstants.fontFamily,
          fontSize: EditorConstants.fontSize,
          height: EditorConstants.lineHeightRatio,
        ),
      ));
    }

    return TextSpan(children: spans);
  }
}
