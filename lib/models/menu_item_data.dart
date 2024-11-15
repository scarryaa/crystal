import 'package:flutter/material.dart';

class MenuItemData {
  final IconData icon;
  final String text;
  final String? shortcut;
  final VoidCallback onTap;
  final bool showDivider;

  const MenuItemData({
    required this.icon,
    required this.text,
    this.shortcut,
    required this.onTap,
    this.showDivider = false,
  });
}
