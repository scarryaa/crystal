import 'package:crystal/models/editor/completion_item.dart';
import 'package:crystal/models/editor/completion_item_kind.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';

class CompletionOverlay extends StatefulWidget {
  final List<CompletionItem> suggestions;
  final Function(CompletionItem) onSelect;
  final Offset position;
  final int selectedIndex;
  final EditorConfigService editorConfigService;

  final itemHeight = 8.0 + 8.0 + (20.0) + (12.0);

  const CompletionOverlay({
    required this.suggestions,
    required this.onSelect,
    required this.position,
    this.selectedIndex = 0,
    required this.editorConfigService,
    super.key,
  });

  @override
  State<CompletionOverlay> createState() => _CompletionOverlayState();
}

class _CompletionOverlayState extends State<CompletionOverlay> {
  final ScrollController _scrollController = ScrollController();

  @override
  void didUpdateWidget(CompletionOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex) {
      _scrollToSelectedItem();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedItem() {
    if (!_scrollController.hasClients) return;

    const double containerHeight = 200;
    final double targetOffset = widget.selectedIndex * widget.itemHeight;

    // Get the current visible range
    final double visibleStart = _scrollController.offset;
    final double visibleEnd =
        visibleStart + _scrollController.position.viewportDimension;

    // Calculate the maximum possible scroll offset
    final double maxScroll = _scrollController.position.maxScrollExtent;

    // Calculate the ideal scroll position to center the item if possible
    double scrollTo = targetOffset - (containerHeight - widget.itemHeight) / 2;

    // Clamp the scroll position between 0 and maxScroll
    scrollTo = scrollTo.clamp(0.0, maxScroll);

    // Only scroll if the item is not fully visible
    if (targetOffset < visibleStart ||
        targetOffset + widget.itemHeight > visibleEnd) {
      _scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.editorConfigService.themeService.currentTheme;

    return Positioned(
      left: widget.position.dx,
      top: widget.position.dy,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 200,
            maxWidth: 300,
          ),
          decoration: BoxDecoration(
            color: theme!.background,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.border),
          ),
          child: ListView.builder(
            controller: _scrollController,
            shrinkWrap: true,
            itemCount: widget.suggestions.length,
            itemBuilder: (context, index) {
              final item = widget.suggestions[index];
              return CompletionItemWidget(
                item: item,
                onSelect: widget.onSelect,
                isSelected: index == widget.selectedIndex,
                editorConfigService: widget.editorConfigService,
              );
            },
          ),
        ),
      ),
    );
  }
}

class CompletionItemWidget extends StatelessWidget {
  final CompletionItem item;
  final Function(CompletionItem) onSelect;
  final bool isSelected;
  final EditorConfigService editorConfigService; // Add this field

  const CompletionItemWidget({
    required this.item,
    required this.onSelect,
    required this.editorConfigService, // Add this parameter
    this.isSelected = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = editorConfigService.themeService.currentTheme;

    return InkWell(
      onTap: () => onSelect(item),
      child: Container(
        color:
            isSelected ? theme!.primary.withOpacity(0.2) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme!.text,
                    ),
                  ),
                  Text(
                    item.detail,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData iconData;
    Color color;

    switch (item.kind) {
      case CompletionItemKind.method:
        iconData = Icons.functions;
        color = Colors.purple;
        break;
      case CompletionItemKind.function:
        iconData = Icons.code;
        color = Colors.blue;
        break;
      case CompletionItemKind.constructor:
        iconData = Icons.build;
        color = Colors.orange;
        break;
      case CompletionItemKind.field:
        iconData = Icons.view_module;
        color = Colors.green;
        break;
      case CompletionItemKind.variable:
        iconData = Icons.category;
        color = Colors.red;
        break;
      case CompletionItemKind.class_:
        iconData = Icons.class_;
        color = Colors.indigo;
        break;
      case CompletionItemKind.interface:
        iconData = Icons.layers;
        color = Colors.teal;
        break;
      case CompletionItemKind.module:
        iconData = Icons.folder;
        color = Colors.amber;
        break;
      case CompletionItemKind.property:
        iconData = Icons.settings;
        color = Colors.deepOrange;
        break;
      case CompletionItemKind.keyword:
        iconData = Icons.key;
        color = Colors.cyan;
        break;
      default:
        iconData = Icons.short_text;
        color = Colors.grey;
    }

    return Icon(iconData, size: 16, color: color);
  }
}
