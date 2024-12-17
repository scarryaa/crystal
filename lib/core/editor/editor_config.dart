import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class EditorConfig {
  double fontSize;
  double uiFontSize;
  FontWeight fontWeight;
  double minGutterWidth;
  String fontFamily;
  Color backgroundColor;
  Color textColor;
  Color gutterTextcolor;
  Color caretColor;
  double caretRadius;
  double selectionRadius;
  double caretWidth;
  int lineBuffer;
  TextDirection? textDirection;

  late double lineHeight;
  late double characterWidth;
  late double widthPadding;
  late double heightPadding;
  late Color selectionColor;

  EditorConfig({
    this.fontSize = 15,
    this.uiFontSize = 15,
    this.fontWeight = FontWeight.w400,
    this.minGutterWidth = 60,
    this.fontFamily = 'IBM Plex Mono',
    this.backgroundColor = Colors.white,
    this.textColor = const Color(0xFF2F3337),
    this.gutterTextcolor = Colors.grey,
    this.caretColor = Colors.blue,
    this.caretRadius = 2.0,
    this.selectionRadius = 2.0,
    this.caretWidth = 2,
    this.lineBuffer = 5,
    this.textDirection,
  }) {
    _initializeDerivedValues();
  }

  void _initializeDerivedValues() {
    lineHeight = _measureLineHeight();
    characterWidth = _measureCharacterWidth();
    selectionColor = caretColor.withOpacity(0.25);
    widthPadding = characterWidth * 12;
    heightPadding = lineHeight * 6;
  }

  double _measureCharacterWidth() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'y',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
        ),
      ),
      textDirection: textDirection ?? TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.width;
  }

  double _measureLineHeight() {
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'Ay',
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: fontSize,
        ),
      ),
      textDirection: textDirection ?? TextDirection.ltr,
    );

    textPainter.layout();
    return textPainter.height;
  }

  static const _defaultConfig = {
    'fontSize': 15.0,
    'uiFontSize': 15.0,
    'fontWeight': 400,
    'fontFamily': 'IBM Plex Mono',
    'uiFontFamily': 'IBM Plex Sans',
    'theme': 'default-dark',
    'isFileExplorerVisible': true,
    'isFileExplorerOnLeft': true,
    'isTerminalVisible': false,
    'currentDirectory': '',
    'fileExplorerWidth': 170.0,
    'tabWidth': 4.0,
    'terminalHeight': 300.0,
  };

  FontWeight getFontWeight(dynamic weight) {
    if (weight is FontWeight) return weight;

    final int numericWeight = weight is int ? weight : 400;

    switch (numericWeight) {
      case 100:
        return FontWeight.w100;
      case 200:
        return FontWeight.w200;
      case 300:
        return FontWeight.w300;
      case 400:
        return FontWeight.w400;
      case 500:
        return FontWeight.w500;
      case 600:
        return FontWeight.w600;
      case 700:
        return FontWeight.w700;
      case 800:
        return FontWeight.w800;
      case 900:
        return FontWeight.w900;
      default:
        return FontWeight.w400;
    }
  }

  Future<void> ensureDefaultAndRegularConfig() async {
    final configDir = await getConfigDirectory();
    final configFile = File('$configDir/config.json');
    final defaultConfigFile = File('$configDir/default_config.json');
    await _ensureConfigFile(configFile);
    await _ensureConfigFile(defaultConfigFile);
  }

  Future<void> loadFromJSON() async {
    try {
      final configDir = await getConfigDirectory();
      final configFile = File('$configDir/config.json');
      await ensureDefaultAndRegularConfig();

      final configContents = await configFile.readAsString();
      if (configContents.isEmpty) {
        await configFile.writeAsString(jsonEncode(_defaultConfig));
      }

      final config = jsonDecode(configContents) as Map<String, dynamic>;

      fontSize = (config['fontSize'] as num).toDouble();
      uiFontSize = (config['uiFontSize'] as num).toDouble();
      fontWeight = getFontWeight(config['fontWeight']);
      fontFamily = config['fontFamily'];

      _initializeDerivedValues();
    } catch (e) {
      debugPrint('Error loading config: $e');
    }
  }

  Future<String> getConfigDirectory() async {
    final supportDir = await getApplicationSupportDirectory();
    final configDir = '${supportDir.path}/crystal';
    await Directory(configDir).create(recursive: true);
    return configDir;
  }

  Future<void> _ensureConfigFile(File configFile) async {
    if (!await configFile.exists()) {
      await configFile.create(recursive: true);

      const encoder = JsonEncoder.withIndent('  ');
      final json = encoder.convert(_defaultConfig);
      await configFile.writeAsString(json);
    }
  }
}
