import 'package:flutter/material.dart';

class WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color color;
  final bool isClose;

  const WindowButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.color,
    this.isClose = false,
  });

  @override
  State<WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<WindowButton> {
  bool isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovering = true),
      onExit: (_) => setState(() => isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: double.infinity,
          color: isHovering
              ? widget.isClose
                  ? Colors.red
                  : widget.color.withOpacity(0.1)
              : Colors.transparent,
          child: Icon(
            widget.icon,
            size: 16,
            color: isHovering && widget.isClose ? Colors.white : widget.color,
          ),
        ),
      ),
    );
  }
}
