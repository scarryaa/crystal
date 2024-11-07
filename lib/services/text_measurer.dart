import 'package:flutter/material.dart';

class TextMeasurer {
  static final TextPainter _textPainter =
      TextPainter(textDirection: TextDirection.ltr);

  double measureLineHeight(String text, String fontFamily, double fontSize) {
    TextSpan ts = TextSpan(
        text: text,
        style: TextStyle(fontFamily: fontFamily, fontSize: fontSize));
    _textPainter.text = ts;

    _textPainter.layout();
    return _textPainter.height;
  }

  double measureTextWidth(String text, String fontFamily, double fontSize) {
    TextSpan ts = TextSpan(
        text: text,
        style: TextStyle(fontFamily: fontFamily, fontSize: fontSize));
    _textPainter.text = ts;

    _textPainter.layout();
    return _textPainter.width;
  }
}
