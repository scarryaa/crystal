import 'package:crystal/models/menu_item_data.dart';
import 'package:flutter/material.dart';

class ContextMenu extends StatelessWidget {
  final List<MenuItemData> menuItems;
  final Color textColor;
  final Color backgroundColor;
  final Color hoverColor;
  final Color dividerColor;
  final RelativeRect position;

  const ContextMenu({
    super.key,
    required this.menuItems,
    required this.textColor,
    required this.backgroundColor,
    required this.hoverColor,
    required this.dividerColor,
    required this.position,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          left: position.left,
          top: position.top,
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: IntrinsicWidth(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _buildMenuItems(context),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> widgets = [];

    for (var i = 0; i < menuItems.length; i++) {
      widgets.add(_buildMenuItem(
        context: context,
        item: menuItems[i],
      ));
    }

    return widgets;
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required MenuItemData item,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            item.onTap();
            Navigator.of(context).pop();
          },
          hoverColor: hoverColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(item.icon, size: 16, color: textColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.text,
                    style: TextStyle(color: textColor),
                  ),
                ),
                if (item.shortcut != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    item.shortcut!,
                    style: TextStyle(
                      color: textColor.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (item.showDivider) Divider(height: 1, color: dividerColor),
      ],
    );
  }
}
