import 'package:crystal/models/editor/config/editor_layout_config.dart';
import 'package:crystal/services/text_measurer.dart';

class EditorLayoutService {
  final TextMeasurer _textMeasurer;
  final EditorLayoutConfig _editorLayoutConfig;

  EditorLayoutService({
    required double horizontalPadding,
    required int verticalPaddingLines,
    required double fontSize,
    required String fontFamily,
    required double lineHeightMultiplier,
  })  : _textMeasurer = TextMeasurer(),
        _editorLayoutConfig = EditorLayoutConfig(
            charWidth:
                TextMeasurer().measureTextWidth('w', fontFamily, fontSize),
            fontSize: fontSize,
            horizontalPadding: horizontalPadding,
            verticalPaddingLines: verticalPaddingLines,
            lineHeightMultiplier: lineHeightMultiplier);

  EditorLayoutConfig get config => _editorLayoutConfig;
}
