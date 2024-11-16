import 'package:crystal/models/editor/command_palette_mode.dart';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CommandItem {
  final String id;
  final String label;
  final String detail;
  final String category;
  final IconData icon;
  final Color iconColor;

  const CommandItem({
    required this.id,
    required this.label,
    required this.detail,
    required this.category,
    required this.icon,
    required this.iconColor,
  });
}

class CommandPalette extends StatefulWidget {
  final List<CommandItem> commands;
  final Function(CommandItem) onSelect;
  final EditorConfigService editorConfigService;
  final CommandPaletteMode initialMode;
  static const double kItemHeight = 44.0;

  const CommandPalette({
    required this.commands,
    required this.onSelect,
    required this.editorConfigService,
    this.initialMode = CommandPaletteMode.commands,
    super.key,
  });

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  int _selectedIndex = 0;
  List<CommandItem> _filteredCommands = [];

  @override
  void initState() {
    super.initState();
    _filteredCommands = widget.commands;
    _searchController.addListener(_handleSearch);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch() {
    final searchTerm = _searchController.text.toLowerCase();
    setState(() {
      _filteredCommands = widget.commands.where((command) {
        return command.label.toLowerCase().contains(searchTerm) ||
            command.detail.toLowerCase().contains(searchTerm) ||
            command.category.toLowerCase().contains(searchTerm);
      }).toList();
      _selectedIndex = 0;
    });
    _scrollToSelectedItem();
  }

  void _scrollToSelectedItem() {
    if (!_scrollController.hasClients) return;

    const double containerHeight = 200;
    final double targetOffset = _selectedIndex * CommandPalette.kItemHeight;
    final double visibleStart = _scrollController.offset;
    final double visibleEnd =
        visibleStart + _scrollController.position.viewportDimension;
    final double maxScroll = _scrollController.position.maxScrollExtent;

    double scrollTo =
        targetOffset - (containerHeight - CommandPalette.kItemHeight) / 2;
    scrollTo = scrollTo.clamp(0.0, maxScroll);

    if (targetOffset < visibleStart ||
        targetOffset + CommandPalette.kItemHeight > visibleEnd) {
      _scrollController.animateTo(
        scrollTo,
        duration: const Duration(milliseconds: 50),
        curve: Curves.easeInOut,
      );
    }
  }

  // ignore: deprecated_member_use
  void _handleKeyPress(RawKeyEvent event) {
    if (_filteredCommands.isEmpty) return;

    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1) % _filteredCommands.length;
        });
        _scrollToSelectedItem();
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        setState(() {
          _selectedIndex = _selectedIndex > 0
              ? _selectedIndex - 1
              : _filteredCommands.length - 1;
        });
        _scrollToSelectedItem();
      } else if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_filteredCommands.isNotEmpty) {
          widget.onSelect(_filteredCommands[_selectedIndex]);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.editorConfigService.themeService.currentTheme;
    final screenSize = MediaQuery.of(context).size;

    // Calculate overlay dimensions
    const overlayWidth = 400.0;
    const overlayHeight = 400.0;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Modal backdrop
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: screenSize.width,
                height: screenSize.height,
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            // Command palette
            Center(
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  constraints: const BoxConstraints(
                    maxHeight: overlayHeight,
                    maxWidth: overlayWidth,
                  ),
                  decoration: BoxDecoration(
                    color: theme!.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: theme.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Search input
                      Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: RawKeyboardListener(
                              focusNode: FocusNode(),
                              onKey: _handleKeyPress,
                              child: TextField(
                                controller: _searchController,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: 'Type a command or search...',
                                  prefixIcon: Icon(Icons.search,
                                      color: theme.textLight),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                style: TextStyle(color: theme.text),
                              ))),
                      // Command list
                      Expanded(
                        child: RawKeyboardListener(
                          focusNode: FocusNode(),
                          onKey: _handleKeyPress,
                          child: ListView.builder(
                            controller: _scrollController,
                            itemCount: _filteredCommands.length,
                            itemBuilder: (context, index) {
                              final command = _filteredCommands[index];
                              return CommandItemWidget(
                                item: command,
                                onSelect: widget.onSelect,
                                isSelected: index == _selectedIndex,
                                editorConfigService: widget.editorConfigService,
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CommandItemWidget extends StatefulWidget {
  final CommandItem item;
  final Function(CommandItem) onSelect;
  final bool isSelected;
  final EditorConfigService editorConfigService;

  const CommandItemWidget({
    required this.item,
    required this.onSelect,
    required this.editorConfigService,
    this.isSelected = false,
    super.key,
  });

  @override
  State<CommandItemWidget> createState() => _CommandItemWidgetState();
}

class _CommandItemWidgetState extends State<CommandItemWidget> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = widget.editorConfigService.themeService.currentTheme;
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: InkWell(
        onTap: () => widget.onSelect(widget.item),
        child: Container(
          height: CommandPalette.kItemHeight,
          color: widget.isSelected
              ? theme!.primary.withOpacity(0.2)
              : isHovered
                  ? theme!.primary.withOpacity(0.1)
                  : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                widget.item.icon,
                size: 16,
                color: widget.item.iconColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.item.label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme!.text,
                      ),
                    ),
                    Text(
                      widget.item.category,
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
      ),
    );
  }
}
