import 'package:flutter/material.dart';

class HighlightedText {
  final String text;
  final Color color;
  final int start;
  final int end;

  HighlightedText({
    required this.text,
    required this.color,
    required this.start,
    required this.end,
  });
}
