import 'package:flutter/material.dart';

class ScrollConfig {
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final VoidCallback scrollToCursor;

  ScrollConfig({
    required this.verticalController,
    required this.horizontalController,
    required this.scrollToCursor,
  });
}
