import 'dart:convert';

import 'package:crystal/models/editor/theme/editor_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class EditorThemeService extends ChangeNotifier {
  EditorTheme? _currentTheme;
  EditorTheme? get currentTheme => _currentTheme;

  Future<void> loadThemeFromJson(String themeName) async {
    try {
      final themeStr =
          await rootBundle.loadString('assets/themes/$themeName.json');
      final themeJson = jsonDecode(themeStr);
      _currentTheme = EditorTheme.fromJson(themeJson);
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to load theme: $themeName. Error: $e');
    }
  }
}
