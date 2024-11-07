import 'package:crystal/models/editor/config/editor_config.dart';
import 'package:crystal/services/editor/editor_theme_service.dart';

class EditorConfigService {
  final EditorThemeService _themeService;
  final EditorConfig _config;

  EditorConfigService({
    required double fontSize,
    required String fontFamily,
    required String theme,
  })  : _themeService = EditorThemeService(),
        _config = EditorConfig(
            fontSize: fontSize,
            fontFamily: fontFamily,
            whitespaceIndicatorRadius: 1.0) {
    _themeService.loadThemeFromJson(theme);
  }

  EditorThemeService get themeService => _themeService;
  EditorConfig get config => _config;
}
