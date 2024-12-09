import 'package:crystal/widgets/editor/managers/editor_tab_controller.dart';
import 'package:flutter/material.dart';

class CustomTabButton extends StatefulWidget {
  final EditorTabController tabController;
  final IconData icon;
  final Function() onPressed;
  final double iconSize;

  const CustomTabButton({
    super.key,
    required this.tabController,
    required this.icon,
    required this.onPressed,
    this.iconSize = 12,
  });

  @override
  State<StatefulWidget> createState() => _CustomTabButtonState();
}

class _CustomTabButtonState extends State<CustomTabButton> {
  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(widget.icon),
      onPressed: widget.onPressed,
      iconSize: widget.iconSize,
    );
  }
}
