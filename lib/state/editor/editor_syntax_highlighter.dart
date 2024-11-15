import 'package:crystal/models/highlighted_text.dart';
import 'package:crystal/models/languages/language.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/services/editor/editor_layout_service.dart';
import 'package:crystal/services/language_detection_service.dart';
import 'package:flutter/material.dart';

class EditorSyntaxHighlighter {
  final List<HighlightedText> highlightedText = [];
  final Language language;
  final EditorLayoutService editorLayoutService;
  final EditorConfigService editorConfigService;

  static final Map<String, List<HighlightedText>> _highlightCache = {};
  static const int _maxCacheSize = 100; // Limit cache size
  String? _lastProcessedText;

  EditorSyntaxHighlighter({
    required String fileName,
    required this.editorLayoutService,
    required this.editorConfigService,
  }) : language = LanguageDetectionService.getLanguageFromFilename(fileName) {
    defaultTextColor = editorConfigService.themeService.currentTheme != null
        ? editorConfigService.themeService.currentTheme!.text
        : Colors.black;
  }

  static const keywordColor = Color(0xFF6B8EFF);
  static const typeColor = Color(0xFF66B2B2);
  static Color stringColor = const Color(0xFF7CB073);
  static const commentColor = Color(0xFFB0B0B0);
  static const numberColor = Color(0xFFFFB366);
  static const symbolColor = Color(0xFFD4A6E3);
  static Color defaultTextColor = Colors.black;

  void highlight(String text) {
    // Return cached result if available
    if (_lastProcessedText == text) {
      return; // Text hasn't changed, keep current highlights
    }

    // Check cache
    if (_highlightCache.containsKey(text)) {
      highlightedText.clear();
      highlightedText.addAll(_highlightCache[text]!);
      _lastProcessedText = text;
      return;
    }

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
    // Cache the results
    _cacheHighlights(text, List.from(highlightedText));
    _lastProcessedText = text;
  }

  void _cacheHighlights(String text, List<HighlightedText> highlights) {
    if (_highlightCache.length >= _maxCacheSize) {
      _highlightCache.remove(_highlightCache.keys.first);
    }
    _highlightCache[text] = highlights;
  }

  static void clearCache() {
    _highlightCache.clear();
  }

  static void removeFromCache(String text) {
    _highlightCache.remove(text);
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
