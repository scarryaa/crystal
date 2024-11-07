import 'package:flutter/material.dart';

class FileExplorerActionBar extends StatelessWidget {
  final VoidCallback? onCollapseAll;
  final VoidCallback? onExpandAll;
  final VoidCallback? onRefresh;
  final Color textColor;

  const FileExplorerActionBar({
    super.key,
    required this.textColor,
    this.onCollapseAll,
    this.onExpandAll,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _buildActionButton(
          icon: Icons.unfold_less,
          tooltip: 'Collapse All',
          onPressed: onCollapseAll,
        ),
        _buildActionButton(
          icon: Icons.unfold_more,
          tooltip: 'Expand All',
          onPressed: onExpandAll,
        ),
        _buildActionButton(
          icon: Icons.refresh,
          tooltip: 'Refresh',
          onPressed: onRefresh,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    VoidCallback? onPressed,
  }) {
    return IconButton(
      icon: Icon(icon),
      color: textColor,
      iconSize: 16.0,
      tooltip: tooltip,
      onPressed: onPressed,
      splashRadius: 20.0,
      constraints: const BoxConstraints(
        minWidth: 32.0,
        minHeight: 32.0,
      ),
    );
  }
}
