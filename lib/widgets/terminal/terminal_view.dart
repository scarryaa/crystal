import 'dart:convert';
import 'dart:io';
import 'package:crystal/services/editor/editor_config_service.dart';
import 'package:crystal/widgets/terminal/terminal_tab.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_pty/flutter_pty.dart';
import 'package:xterm/xterm.dart';

class EditorTerminalView extends StatefulWidget {
  final EditorConfigService editorConfigService;
  final VoidCallback? onLastTabClosed;

  const EditorTerminalView({
    super.key,
    required this.editorConfigService,
    this.onLastTabClosed,
  });

  @override
  State<EditorTerminalView> createState() => _EditorTerminalViewState();
}

class _EditorTerminalViewState extends State<EditorTerminalView>
    with TickerProviderStateMixin {
  final ScrollController _tabScrollController = ScrollController();
  static const double _kSpacing = 8.0;
  static const double _kHorizontalPadding = 16.0;

  late TabController _tabController;
  final List<TerminalTab> _tabs = [];
  int _tabCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 0, vsync: this, animationDuration: Duration.zero);
    _addNewTab();
  }

  void _closeTab(int index) {
    setState(() {
      _tabs[index].pty.kill();
      _tabs.removeAt(index);

      if (_tabs.isEmpty) {
        widget.editorConfigService.config.isTerminalVisible = false;
        widget.editorConfigService.saveConfig();

        // Call the callback when last tab is closed
        widget.onLastTabClosed?.call();
      } else {
        _tabController = TabController(
          length: _tabs.length,
          vsync: this,
          animationDuration: Duration.zero,
        );
      }
    });
  }

  Widget _buildTabButton(TerminalTab tab, int index) {
    final theme = widget.editorConfigService.themeService.currentTheme;
    final isActive = _tabController.index == index;
    final color = isActive
        ? theme?.primary ?? Colors.blue
        : theme?.text ?? Colors.black54;

    return MouseRegion(
      child: GestureDetector(
        onTap: () => _closeTab(index),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _closeTab(index),
              hoverColor: theme?.backgroundLight ?? Colors.black12,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: widget.editorConfigService.config.uiFontSize,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTabContextMenu(
      BuildContext context, TapDownDetails details, int index) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(details.globalPosition, details.globalPosition),
      Offset.zero & overlay.size,
    );

    final theme = widget.editorConfigService.themeService.currentTheme;
    final textColor = theme?.text ?? Colors.black87;
    final backgroundColor = theme?.background ?? Colors.white;

    showMenu(
      context: context,
      position: position,
      color: backgroundColor.withRed(30).withBlue(30).withGreen(30),
      items: [
        PopupMenuItem(
          onTap: () => _closeTab(index),
          child: Row(
            children: [
              Icon(Icons.close, size: 18, color: textColor),
              const SizedBox(width: _kSpacing),
              Text(
                'Close',
                style: TextStyle(color: textColor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _addNewTab() {
    setState(() {
      _tabCount++;
      final newTab = TerminalTab(title: 'Terminal $_tabCount');
      _tabs.add(newTab);
      _tabController = TabController(
          length: _tabs.length, vsync: this, animationDuration: Duration.zero);
      _tabController.index = _tabs.length - 1;

      WidgetsBinding.instance.endOfFrame.then((_) {
        if (mounted) _startPty(newTab);
      });
    });
  }

  void _startPty(TerminalTab tab) {
    tab.pty = Pty.start(
      _getShell(),
      columns: tab.terminal.viewWidth,
      rows: tab.terminal.viewHeight,
    );

    tab.pty.output
        .cast<List<int>>()
        .transform(const Utf8Decoder())
        .listen(tab.terminal.write);

    tab.pty.exitCode.then((code) {
      tab.terminal.write('Process exited with code $code');
    });

    tab.terminal.onOutput = (data) {
      tab.pty.write(const Utf8Encoder().convert(data));
    };

    tab.terminal.onResize = (w, h, pw, ph) {
      tab.pty.resize(h, w);
    };
  }

  String _getShell() {
    if (Platform.isMacOS || Platform.isLinux) {
      return Platform.environment['SHELL'] ?? 'bash';
    }
    if (Platform.isWindows) {
      return 'cmd.exe';
    }
    return 'sh';
  }

  @override
  Widget build(BuildContext context) {
    if (_tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = widget.editorConfigService.themeService.currentTheme;
    final scrollController = ScrollController();

    return Column(
      children: [
        Container(
          color: theme?.backgroundLight ?? Colors.grey[50],
          child: Row(
            children: [
              Expanded(
                child: _tabs.isEmpty
                    ? const SizedBox()
                    : Listener(
                        onPointerSignal: (PointerSignalEvent event) {
                          if (event is PointerScrollEvent) {
                            if (event.scrollDelta.dy != 0) {
                              if (HardwareKeyboard.instance.isShiftPressed) {
                                // Shift + Scroll: Switch tabs
                                final newIndex = _tabController.index +
                                    (event.scrollDelta.dy > 0 ? 1 : -1);
                                if (newIndex >= 0 && newIndex < _tabs.length) {
                                  setState(() {
                                    _tabController.index = newIndex;
                                  });
                                }
                              } else {
                                // Regular scroll: Scroll tabs horizontally
                                scrollController.position.moveTo(
                                  scrollController.offset +
                                      event.scrollDelta.dy,
                                  curve: Curves.linear,
                                );
                              }
                            }
                          }
                        },
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          child: TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            padding: EdgeInsets.zero,
                            labelPadding: EdgeInsets.zero,
                            tabAlignment: TabAlignment.start,
                            dividerColor: Colors.transparent,
                            indicatorColor: Colors.transparent,
                            tabs: _tabs.asMap().entries.map((entry) {
                              final index = entry.key;
                              final tab = entry.value;
                              final isActive = _tabController.index == index;

                              return DragTarget<int>(
                                onAcceptWithDetails: (details) {
                                  final draggedIndex = details.data;
                                  setState(() {
                                    final draggedTab =
                                        _tabs.removeAt(draggedIndex);
                                    _tabs.insert(index, draggedTab);
                                    _tabController = TabController(
                                      length: _tabs.length,
                                      vsync: this,
                                      animationDuration: Duration.zero,
                                    );
                                    _tabController.index = index;
                                  });
                                },
                                builder:
                                    (context, candidateData, rejectedData) {
                                  return Draggable<int>(
                                    data: index,
                                    feedback: Material(
                                      elevation: 4,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: _kHorizontalPadding,
                                        ),
                                        color:
                                            theme?.background ?? Colors.white,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              tab.title,
                                              style: TextStyle(
                                                color: theme?.primary ??
                                                    Colors.blue,
                                                fontSize: widget
                                                    .editorConfigService
                                                    .config
                                                    .uiFontSize,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    child: MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _tabController.index = index;
                                          });
                                        },
                                        child: Container(
                                          height: widget.editorConfigService
                                                  .config.uiFontSize *
                                              2.5,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: _kHorizontalPadding,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? theme?.background ??
                                                    Colors.white
                                                : theme?.backgroundLight ??
                                                    Colors.grey[50],
                                            border: Border(
                                              right: BorderSide(
                                                color: theme?.border ??
                                                    Colors.grey[200]!,
                                              ),
                                            ),
                                          ),
                                          child: GestureDetector(
                                            onSecondaryTapDown: (details) =>
                                                _showTabContextMenu(
                                                    context, details, index),
                                            onTertiaryTapDown: (_) =>
                                                _closeTab(index),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  tab.title,
                                                  style: TextStyle(
                                                    color: isActive
                                                        ? theme?.primary ??
                                                            Colors.blue
                                                        : theme?.text ??
                                                            Colors.black87,
                                                    fontSize: widget
                                                        .editorConfigService
                                                        .config
                                                        .uiFontSize,
                                                  ),
                                                ),
                                                const SizedBox(
                                                    width: _kSpacing),
                                                _buildTabButton(tab, index),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ),
              ),
              IconButton(
                icon: Icon(
                  Icons.add,
                  color: theme?.text ?? Colors.black87,
                  size: widget.editorConfigService.config.uiFontSize,
                ),
                onPressed: _addNewTab,
                tooltip: 'New Terminal',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            physics: const NeverScrollableScrollPhysics(),
            controller: _tabController,
            children: _tabs.map((tab) {
              return TerminalView(
                tab.terminal,
                controller: tab.controller,
                autofocus: true,
                textStyle: TerminalStyle(
                  fontSize: widget.editorConfigService.config.fontSize,
                  fontFamily: widget.editorConfigService.config.fontFamily,
                ),
                onSecondaryTapDown: (details, offset) async {
                  final selection = tab.controller.selection;
                  if (selection != null) {
                    final text = tab.terminal.buffer.getText(selection);
                    tab.controller.clearSelection();
                    await Clipboard.setData(ClipboardData(text: text));
                  } else {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text;
                    if (text != null) {
                      tab.terminal.paste(text);
                    }
                  }
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tabScrollController.dispose();
    for (var tab in _tabs) {
      tab.pty.kill();
    }
    _tabController.dispose();
    super.dispose();
  }
}
