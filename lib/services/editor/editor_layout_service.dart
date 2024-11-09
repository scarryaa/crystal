import 'package:crystal/models/editor/config/editor_layout_config.dart';
import 'package:crystal/services/text_measurer.dart';

class EditorLayoutService {
  static EditorLayoutService? _instance;
  final TextMeasurer _textMeasurer;
  late EditorLayoutConfig _editorLayoutConfig;

  EditorLayoutService._({
    required double horizontalPadding,
    required int verticalPaddingLines,
    required double fontSize,
    required String fontFamily,
    required double lineHeightMultiplier,
  }) : _textMeasurer = TextMeasurer() {
    _updateConfig(
      horizontalPadding: horizontalPadding,
      verticalPaddingLines: verticalPaddingLines,
      fontSize: fontSize,
      fontFamily: fontFamily,
      lineHeightMultiplier: lineHeightMultiplier,
    );
  }

  factory EditorLayoutService({
    required double horizontalPadding,
    required int verticalPaddingLines,
    required double fontSize,
    required String fontFamily,
    required double lineHeightMultiplier,
  }) {
    _instance ??= EditorLayoutService._(
      horizontalPadding: horizontalPadding,
      verticalPaddingLines: verticalPaddingLines,
      fontSize: fontSize,
      fontFamily: fontFamily,
      lineHeightMultiplier: lineHeightMultiplier,
    );
    return _instance!;
  }

  static EditorLayoutService get instance {
    if (_instance == null) {
      throw StateError('EditorLayoutService not initialized');
    }
    return _instance!;
  }

  void updateFontSize(double newFontSize, String fontFamily) {
    _updateConfig(
      horizontalPadding: _editorLayoutConfig.horizontalPadding,
      verticalPaddingLines: _editorLayoutConfig.verticalPaddingLines,
      fontSize: newFontSize,
      fontFamily: fontFamily,
      lineHeightMultiplier: _editorLayoutConfig.lineHeightMultiplier,
    );
  }

  void _updateConfig({
    required double horizontalPadding,
    required int verticalPaddingLines,
    required double fontSize,
    required String fontFamily,
    required double lineHeightMultiplier,
  }) {
    _editorLayoutConfig = EditorLayoutConfig(
      charWidth: _textMeasurer.measureTextWidth('w', fontFamily, fontSize),
      fontSize: fontSize,
      horizontalPadding: horizontalPadding,
      verticalPaddingLines: verticalPaddingLines,
      lineHeightMultiplier: lineHeightMultiplier,
    );
  }

  EditorLayoutConfig get config => _editorLayoutConfig;

  static void reset() {
    _instance = null;
  }
}
